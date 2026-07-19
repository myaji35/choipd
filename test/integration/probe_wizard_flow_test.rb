# frozen_string_literal: true

require "test_helper"

# ISS-403 Golden Scenarios:
# 1. 가입+동의 → probe 완료 → S1~S6 순차 진행 → 공개 페이지 도착
# 2. 가입+동의 거부 → probe skip (공개 페이지 직행)
# 3. S3에서 중단 → 24h 내 재진입 → last_step 재개
# 4. S1 "제가 아니에요" → 모든 결과 폐기 → S2 빈 상태
# 5. LLM timeout → 부분 결과로 S2부터 시작
class ProbeWizardFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def signup_member(consent:, email: nil)
    email ||= "flow-#{SecureRandom.hex(4)}@example.com"
    post "/auth/signup", params: {
      member: {
        name: "흐름#{SecureRandom.hex(2)}",
        email: email,
        slug: "flow-#{SecureRandom.hex(4)}",
        password: "password1234",
        password_confirmation: "password1234",
        business_type: "individual",
        profession: "custom",
        region: "서울",
      },
      identity_probe_consent: consent ? "1" : "0",
      terms_agree: "1", # 가입 필수 동의(ISS-116)
    }
    Member.find_by(email: email)
  end

  def log_in(member)
    # MemberAuthController#create 경로.
    post "/auth/login", params: { email: member.email, password: "password1234" }
    follow_redirect! if response.redirect?
  end

  # ── Scenario 1: 가입+동의 → probe 완료 → S1~S6 → 공개 페이지 도착 ────────
  test "scenario 1: signup with consent runs full wizard and lands on public page" do
    member = perform_enqueued_jobs(only: IdentityProbeJob) do
      signup_member(consent: true)
    end
    assert_not_nil member
    probe = IdentityProbe.where(member_id: member.id).order(created_at: :desc).first
    assert_not_nil probe
    # Mock fallback 기준으로 job은 completed로 수렴한다.
    assert_equal "completed", probe.status

    # 로그인 세션 확보 후 위자드 진입.
    log_in(member)
    get "/welcome/probe"
    assert_response :success

    # S1~S5 순차 전진 (PATCH로 advance_step!).
    patch "/welcome/probe/step/1", params: { payload: { candidate_id: "c1" } }
    follow_redirect!
    patch "/welcome/probe/step/2", params: { payload: { profession: "스마트폰 강사", region: "서울 강남구" } }
    follow_redirect!
    patch "/welcome/probe/step/3", params: { payload: { links: [{ platform: "instagram", url: "https://instagram.com/x" }] } }
    follow_redirect!
    patch "/welcome/probe/step/4", params: { payload: { bio: "저는 ~입니다." } }
    follow_redirect!
    patch "/welcome/probe/step/5", params: { payload: { url: "" } }
    follow_redirect!

    # S6 최종 — 필수 2개 동의 체크 후 finish.
    post "/welcome/probe/finish", params: { consents: { publish: "1", share: "1" } }
    assert_redirected_to "/#{member.slug}"

    probe.reload
    assert_equal "completed", probe.status
    assert_equal "accepted", probe.user_decision
  end

  # ── Scenario 2: 가입+동의 거부 → probe skip (공개 페이지 직행) ────────
  test "scenario 2: signup without consent skips probe and goes to public page directly" do
    member = nil
    assert_no_enqueued_jobs only: IdentityProbeJob do
      member = signup_member(consent: false)
    end
    assert_not_nil member
    assert_redirected_to "/#{member.slug}"
    assert_equal 0, IdentityProbe.where(member_id: member.id).count
  end

  # ── Scenario 3: S3에서 중단 → 24h 내 재진입 → last_step 재개 ────────
  test "scenario 3: resuming within 24h returns to last_step" do
    member = perform_enqueued_jobs(only: IdentityProbeJob) do
      signup_member(consent: true)
    end
    log_in(member)

    # S1, S2, S3까지 진행 후 브라우저 닫음 (세션 유지 상태로 재진입).
    patch "/welcome/probe/step/1", params: { payload: { candidate_id: "c1" } }
    follow_redirect!
    patch "/welcome/probe/step/2", params: { payload: { profession: "코치" } }
    follow_redirect!
    patch "/welcome/probe/step/3", params: { payload: { links: [] } }
    follow_redirect!

    probe = IdentityProbe.where(member_id: member.id).order(created_at: :desc).first
    assert_equal 3, probe.last_step

    # expires_at 아직 미래 → 재진입 가능.
    assert probe.expires_at > Time.current

    get "/welcome/probe"
    assert_response :success
    # URL 파라미터가 없으면 last_step 기반 재개. status="completed" + last_step=3 → 3 쪽이 렌더되어야.
    # 뷰 구현상 3단계 파셜이 렌더됨을 확인.
    assert_match(/s3|SNS|링크|step/i, response.body)
  end

  # ── Scenario 4: S1 "제가 아니에요" → 모든 결과 폐기 → S2 빈 상태 ────────
  test "scenario 4: S1 'not me' clears candidates and advances to empty S2" do
    member = perform_enqueued_jobs(only: IdentityProbeJob) do
      signup_member(consent: true)
    end
    log_in(member)

    probe = IdentityProbe.where(member_id: member.id).order(created_at: :desc).first
    assert_not_nil probe

    # S1 "제가 아니에요" = candidate_id 없이 rejected_candidates 저장.
    patch "/welcome/probe/step/1", params: { payload: { rejected: true, candidate_id: nil } }
    follow_redirect!

    probe.reload
    assert_equal 1, probe.last_step
    # params를 통해 들어오므로 문자열 "true"로 저장됨.
    rejected = probe.step_payloads.dig("s1", "rejected")
    assert_includes [true, "true"], rejected

    # S2가 렌더되는지 확인 (URL 파라미터 step=2 전달).
    get "/welcome/probe", params: { step: 2 }
    assert_response :success
  end

  # ── Scenario 5: LLM timeout → 부분 결과로 S2부터 시작 ────────
  test "scenario 5: LLM timeout still allows wizard to open with partial data" do
    # Job을 실행하지 않고 probe를 수동 생성해서 "timeout 결과" 시뮬레이션.
    member = signup_member(consent: true)
    # 이 시점 follow_redirect 전에 Member는 만들어짐. 다른 테스트들과 달리 Job을 enqueue만 해두고 실행은 안 함.
    clear_enqueued_jobs
    log_in(member)

    # timeout 후의 상태: status="completed"지만 identity.candidates가 없고, hints만 채워짐.
    IdentityProbe.create!(
      member: member,
      status: "completed",
      confidence: 0.1,
      identity: {
        "profile" => { "confidence" => 0.1, "display_name" => member.name },
        "structured" => {},
        "hints" => { "email" => member.email, "name" => member.name },
        "mock_mode" => true,
      },
      sources_queried: %w[gravatar google naver instagram],
      sources_hit: [],
      raw_signals: [],
      step_payloads: {},
      last_step: 0,
    )

    get "/welcome/probe", params: { step: 2 }
    assert_response :success
    # 위자드가 죽지 않고 S2를 렌더할 수 있어야 한다.
  end
end
