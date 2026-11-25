require "test_helper"

class MemberDashboardProfileAccountsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @member = Member.create!(
      name: "테스트 회원", email: "dashboard-profile@example.test", slug: "dashboard-profile",
      status: "approved", business_type: "individual", profession: "custom",
      password: "password1234", password_confirmation: "password1234"
    )
  end

  test "회원에게 두 플랫폼의 미연결 상태를 표시한다" do
    sign_in_member
    visit_dashboard

    assert_select "#profile-accounts-status" do
      assert_select "article h3", text: "네이버 계정 등록 전"
      assert_select "article h3", text: "LinkedIn 계정 등록 전"
      assert_select "article p", text: "네이버 계정을 등록하면 네이버 인물정보 등록·수정 요청을 대신 진행해요."
      assert_select "article p", text: "LinkedIn 계정을 등록하면 프로필 점검과 업데이트를 대신 진행해요."
      assert_select "article p", text: "맡기려면 운영팀에 말씀해 주세요.", count: 2
      assert_select "article ol li", text: /○/, count: 6
      assert_select "article .impd-label-muted", count: 2 do |labels|
        assert_equal [ "네이버 인물정보", "LinkedIn" ], labels.map(&:text)
      end
    end
    assert_select "a[href^='/pd/']", count: 0
  end

  test "LinkedIn 수집 정보와 네이버 등록 및 반영 요청 상태를 표시한다" do
    freeze_time
    linkedin = @member.profile_accounts.create!(
      platform: "linkedin", display_name: "LinkedIn 테스트 프로필", headline: "대표",
      login_id: "kangss@example.com", session_status: "logged_in", last_checked_at: 2.days.ago,
      profile_url: "https://www.linkedin.com/in/example"
    )
    linkedin.profile_snapshots.create!(
      captured_at: 1.day.ago, data: { pages: { profile: { text: "테스트 회원\n대표" } } }.to_json
    )
    naver = @member.profile_accounts.create!(platform: "naver_people", display_name: "네이버 테스트 프로필")
    naver.create_naver_people_target!(status: "approved")
    naver.naver_people_submissions.create!(status: "filled", created_at: 2.days.ago)
    submission = naver.naver_people_submissions.create!(status: "submitted", created_at: 1.day.ago)

    sign_in_member
    visit_dashboard

    assert_select "#profile-accounts-status article:first-child" do
      assert_select "details summary", text: "자세히 보기"
      assert_select "details p", text: "올릴 내용: 확정"
      assert_select "article > p", text: "운영팀이 준비하고 있어요. 끝나면 여기에 표시돼요."
      assert_select "p", text: "맡긴 계정: 아직 등록 안 됨"
      assert_select "ol li", text: /✓ 계정 맡기기/
      assert_select "ol li", text: /○ 로그인 확인/
      assert_select "ol li", text: "✓ 내용 손보기"
      assert_select "p", text: "네이버에 고쳐 달라고 한 날: #{submission.created_at.in_time_zone("Asia/Seoul").strftime("%Y.%m.%d %H:%M")} (제출함)"
    end
    assert_select "#profile-accounts-status article:last-child" do
      assert_select "h3", text: linkedin.display_name
      assert_select "p", text: "맡긴 계정: ka***@example.com"
      assert_select "ol li", text: /✓/, count: 3
      assert_select "span", text: "로그인됨"
      assert_select "details:not([open])" do
        assert_select "summary", text: "자세히 보기"
        assert_select "p", text: "운영팀이 마지막으로 확인: 2일 전"
      end
      assert_select "article > p", text: "운영팀이 관리하고 있어요. 따로 하실 일은 없어요."
      assert_select "p", text: /\bdays\b/, count: 0
      assert_select "p", text: /프로필 완성도 \d+%/
      assert_select "progress[max='100'][value]"
      assert_select "a[href=?][target='_blank'][rel='noopener']", linkedin.profile_url, text: "프로필 열기 ↗"
    end
    assert_not_includes response.body, "kangss@example.com"
    assert_select "a", text: "관리 화면에서 열기", count: 0
    assert_select "a[href^='/pd/']", count: 0
  end

  test "운영자 대리 접속 중에는 연결 여부에 맞는 관리 링크를 표시한다" do
    account = @member.profile_accounts.create!(platform: "linkedin", display_name: "테스트 프로필")
    sign_in AdminUser.create!(email: "dashboard-staff@example.test", password: "password123", role: "admin")

    visit_dashboard

    assert_select "#profile-accounts-status a[href=?]", pd_profile_account_path(account), text: "관리 화면에서 열기"
    assert_select "#profile-accounts-status a[href=?]", new_pd_profile_account_path(member_id: @member.id),
      text: "관리 화면에서 열기"
  end

  test "오류 상세를 숨기고 잘못된 LinkedIn 스냅샷은 완성도에서 생략한다" do
    account = @member.profile_accounts.create!(
      platform: "linkedin", display_name: "오류 상태 프로필", session_status: "error",
      last_error: "운영자용 오류 상세 메시지", profile_url: "javascript:alert(1)"
    )

    sign_in_member
    [ "{", { experiences: 5 } ].each do |data|
      account.profile_snapshots.create!(captured_at: Time.current, data: data)
      visit_dashboard

      assert_select "#profile-accounts-status span", text: "오류"
      assert_select "#profile-accounts-status p", text: "로그인에 문제가 있어 운영팀이 확인하고 있어요. 따로 하실 일은 없어요."
      assert_select "#profile-accounts-status progress", count: 0
      assert_select "#profile-accounts-status a", text: "프로필 열기 ↗", count: 0
      assert_not_includes response.body, account.last_error
    end
  end

  private

  def sign_in_member
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  def visit_dashboard
    get slug_admin_dashboard_path(slug: @member.slug)
    assert_response :success
  end
end
