# frozen_string_literal: true

# ISS-402: Identity Probe Wizard (6-step) 프론트엔드 컨트롤러.
# /welcome/probe — 회원 가입 직후 "imPD가 당신을 대신 찾아드릴게요" 위자드.
#
# - S0 로딩: IdentityProbeJob 결과 폴링
# - S1 인물 확인: probe.identity.candidates 중 선택
# - S2 직업/지역: 칩 선택 또는 직접 입력
# - S3 SNS 링크: 체크박스 확정
# - S4 Bio 초안: 매니페스토 톤 수락/재작성/직접 입력
# - S5 프로필 사진: 후보 카드 중 선택 또는 업로드
# - S6 최종 동의: 4개 마이크로 동의 → Member 반영 → redirect /:slug
class IdentityProbesController < ApplicationController
  layout "impd"

  TOTAL_STEPS  = 6 # S1~S6 (S0는 로딩이므로 진행 바 기준에서 0)
  MAX_STEP_IDX = 6

  before_action :require_member_login!
  before_action :load_probe, except: [ :show ]

  # GET /welcome/probe
  # 최신 probe 찾기. 없으면 status="pending"으로 생성 (IdentityProbeJob이 아직 안 돌았을 수도 있음).
  def show
    @probe = current_member.identity_probes.order(created_at: :desc).first

    if @probe.nil?
      @probe = current_member.identity_probes.create!(
        status: "pending",
        last_step: 0,
      )
    end

    # status="rejected" 혹은 "expired"면 새 probe를 기대하지 않음 → S1 빈 모드 또는 직접 입력.
    # 완료된 probe라면 재진입 시 마지막 스텝 or S6부터.
    @current_step = resolve_current_step(@probe)
    @identity      = normalized_identity(@probe)
    @total_steps   = TOTAL_STEPS
    @progress_pct  = progress_percent(@current_step)
  end

  # GET /welcome/probe/status — S0 로딩 폴링 엔드포인트
  def status
    render json: {
      status: @probe.status,
      last_step: @probe.last_step,
      sources_hit: safe_json_array(@probe.sources_hit),
      sources_queried: safe_json_array(@probe.sources_queried),
      progress_percent: s0_progress_percent(@probe),
      candidates_count: normalized_identity(@probe).dig("candidates")&.size.to_i,
    }
  end

  # PATCH /welcome/probe/step/:n
  # payload: { payload: {...} } — step_payloads["s<n>"]에 저장 + last_step 갱신.
  def update_step
    step = params[:n].to_i
    return head :bad_request unless step.between?(1, MAX_STEP_IDX)

    # payload가 비거나 누락이어도 "다음"은 허용 — 빈 해시로 정규화 후 저장.
    raw_payload = params[:payload]
    payload = if raw_payload.is_a?(ActionController::Parameters)
                raw_payload.permit!.to_h
              elsif raw_payload.is_a?(Hash)
                raw_payload
              else
                {}
              end
    @probe.advance_step!(step, payload)

    next_step = [ step + 1, MAX_STEP_IDX ].min
    # Turbo Frame이 302를 받으면 PATCH를 유지한 채 Location을 따라감 → 라우트 매칭 실패.
    # 303 See Other로 보내면 method가 GET으로 강제 전환됨.
    redirect_to probe_wizard_show_path(step: next_step), status: :see_other
  end

  # POST /welcome/probe/finish
  # 4개 동의 체크 + 최종 확정 → Member에 bio/avatar/social 반영 → /:slug 리다이렉트.
  def finish
    consents = params[:consents].is_a?(ActionController::Parameters) ? params[:consents].permit!.to_h : {}
    required_publish = consents["publish"].to_s == "1" || consents["publish"] == true
    required_share   = consents["share"].to_s   == "1" || consents["share"] == true

    unless required_publish && required_share
      redirect_to probe_wizard_show_path(step: 6, error: "required_consent_missing"), status: :see_other and return
    end

    apply_probe_to_member!(@probe, consents)
    @probe.finalize!("accepted")

    redirect_to "/#{current_member.slug}", status: :see_other, notice: "공개 페이지가 준비됐어요."
  end

  # POST /welcome/probe/skip
  def skip
    @probe.update(status: "rejected", user_decision: "rejected", decided_at: Time.current)
    redirect_to "/#{current_member.slug}", status: :see_other, notice: "나중에 프로필 관리에서 이어갈 수 있어요."
  end

  # POST /welcome/probe/rewrite_bio
  # S4에서 "다른 표현으로 다시 써줘" 버튼 — 실제 LLM 호출은 ISS-401 백엔드에서.
  # 프론트 구현에서는 mock 3개 variation을 순환 반환 (backend 미완성 대비).
  def rewrite_bio
    current_index = params[:index].to_i
    variations = mock_bio_variations
    next_index = (current_index + 1) % variations.size
    render json: {
      bio: variations[next_index],
      index: next_index,
      total: variations.size,
    }
  end

  private

  def require_member_login!
    return if current_member

    redirect_to member_login_path, alert: "로그인이 필요합니다."
  end

  def load_probe
    @probe = current_member.identity_probes.order(created_at: :desc).first
    return if @probe

    # 엣지: 누군가 직접 API 호출을 시도. pending probe 생성.
    @probe = current_member.identity_probes.create!(status: "pending", last_step: 0)
  end

  # S0는 probe.status 기반, 그 외는 last_step + (URL 파라미터 step) 조합.
  def resolve_current_step(probe)
    url_step = params[:step].to_i
    return url_step if url_step.between?(1, MAX_STEP_IDX)

    case probe.status
    when "pending", "in_progress"
      0 # S0 로딩
    when "completed"
      # 결과 도달, last_step 기반 재개
      [ probe.last_step.to_i, 1 ].max.clamp(1, MAX_STEP_IDX)
    when "rejected", "expired", "failed"
      1 # S1 빈 모드 또는 직접 입력 허용
    else
      0
    end
  end

  def progress_percent(step)
    return 0 if step.zero?
    ((step.to_f / TOTAL_STEPS) * 100).round
  end

  # S0 로딩 화면의 0~100% 진행도 (sources_queried/sources_hit 기반)
  def s0_progress_percent(probe)
    queried = safe_json_array(probe.sources_queried).size
    max_sources = 4 # Gravatar, Google, Naver, IG
    base = (queried.to_f / max_sources * 80).round
    case probe.status
    when "completed" then 100
    when "failed", "expired" then 100
    else [ base, 95 ].min
    end
  end

  # probe.identity는 아래 두 schema 중 하나로 올 수 있다.
  # (A) 프론트 예상: { candidates, professions, regions, sns_links, bio_draft, avatars }
  # (B) 백엔드(ISS-401) 현재: { profile, structured, hints, mock_mode }
  # 둘 다 수용하도록 어댑팅. 완전히 비어있으면 mock fallback.
  def normalized_identity(probe)
    raw = probe.identity
    parsed = raw.is_a?(Hash) ? raw : (JSON.parse(raw.to_s) rescue nil)
    return mock_identity_fallback(probe) if parsed.blank?

    # (A) 프론트 스키마 그대로
    return parsed if parsed.key?("candidates") || parsed.key?("professions")

    # (B) 백엔드 스키마 → 프론트 스키마로 어댑팅
    if parsed.key?("profile") || parsed.key?("structured")
      return adapt_backend_identity(parsed, probe)
    end

    mock_identity_fallback(probe)
  rescue => e
    Rails.logger.warn("[IdentityProbe#normalize] #{e.class}: #{e.message}")
    mock_identity_fallback(probe)
  end

  # 백엔드 (profile/structured/hints) → 프론트 (candidates/professions/regions/...) 어댑터.
  # 백엔드 결과가 빈약하면(mock_mode) 여전히 mock_identity_fallback 기반 보강을 섞는다.
  def adapt_backend_identity(be, probe)
    profile    = be["profile"]    || {}
    structured = be["structured"] || {}

    roles   = Array(profile["professional_roles"]) + Array(structured["candidate_roles"])
    regions = Array(structured["candidate_regions"])
    city    = profile.dig("region", "city").to_s
    country = profile.dig("region", "country").to_s
    region_label = [ city, country ].reject(&:blank?).join(" · ")
    links = Array(profile["links"]) + Array(structured["links"])

    display_name = profile["display_name"].presence || current_member.name.to_s
    mock = mock_identity_fallback(probe)

    # 후보 1명(백엔드는 단일 profile 반환). 신뢰도가 0.1 같이 매우 낮으면 후보 UI는 비워서 "제가 아니에요" 길로 유도.
    confidence = (profile["confidence"].to_f * 100).round
    candidates = []
    if confidence >= 40
      candidates << {
        "id" => "backend-c1",
        "name" => display_name,
        "title" => roles.first,
        "region" => region_label.presence,
        "avatar_url" => nil,
        "confidence" => confidence,
        "sources" => (profile["sources"] || structured["sources"] || []).map { |s| s.to_s },
        "source_quote" => profile["bio_source_quote"].to_s,
      }
    end

    professions = roles.uniq.first(4).map.with_index do |r, idx|
      { "label" => r.to_s, "confidence" => [ 80 - idx * 8, 40 ].max, "source" => "백엔드", "quote" => "" }
    end
    professions = mock["professions"] if professions.empty?

    region_chips = regions.uniq.first(3).map.with_index do |r, idx|
      { "label" => r.to_s, "confidence" => [ 75 - idx * 10, 40 ].max, "source" => "백엔드", "quote" => "" }
    end
    if region_chips.empty? && region_label.present?
      region_chips << { "label" => region_label, "confidence" => 60, "source" => "백엔드", "quote" => "" }
    end
    region_chips = mock["regions"] if region_chips.empty?

    sns_links = links.uniq { |l| l["url"] }.first(6).map do |l|
      {
        "platform" => (l["source"] || "manual").to_s.downcase.gsub("oembed", ""),
        "url" => l["url"].to_s,
        "handle" => l["url"].to_s,
        "confidence" => 70,
      }
    end
    sns_links = mock["sns_links"] if sns_links.empty?

    bio_draft = profile["bio_draft"].presence || mock["bio_draft"]
    avatars = mock["avatars"] # 백엔드 아바타 소스 미구현 — 프론트 mock 유지

    {
      "candidates" => candidates,
      "professions" => professions,
      "regions" => region_chips,
      "sns_links" => sns_links,
      "bio_draft" => bio_draft,
      "avatars" => avatars,
      "_backend_confidence" => confidence,
      "_backend_mock_mode" => be["mock_mode"] == true,
    }
  end

  def safe_json_array(value)
    return value if value.is_a?(Array)
    return [] if value.blank?
    JSON.parse(value) rescue []
  end

  # ISS-401 백엔드가 아직 완성 안됐을 가능성에 대비한 mock identity.
  # member.name / member.email 만으로 상식적 후보 생성.
  def mock_identity_fallback(probe)
    name = current_member.name.to_s
    email_local = current_member.email.to_s.split("@").first

    {
      "candidates" => [
        {
          "id" => "c1",
          "name" => name.presence || email_local,
          "title" => "스마트폰 강사",
          "region" => "서울 강남구",
          "avatar_url" => nil,
          "confidence" => 82,
          "sources" => [ "google", "naver" ],
          "source_quote" => "@#{email_local} · 네이버 블로그 · 최근 30일",
        },
        {
          "id" => "c2",
          "name" => name.presence || email_local,
          "title" => "요가 지도사",
          "region" => "서울 마포구",
          "avatar_url" => nil,
          "confidence" => 61,
          "sources" => [ "instagram" ],
          "source_quote" => "인스타그램 @yoga_#{email_local} · 공개 프로필",
        },
      ],
      "professions" => [
        { "label" => "스마트폰 강사", "confidence" => 88, "source" => "네이버 블로그", "quote" => "스마트폰 창업 3기 강의 진행" },
        { "label" => "콘텐츠 크리에이터", "confidence" => 72, "source" => "유튜브 채널", "quote" => "구독자 1.2만명" },
        { "label" => "1인 사업가", "confidence" => 65, "source" => "브런치", "quote" => "4050 시니어 창업 에세이" },
      ],
      "regions" => [
        { "label" => "서울 강남구", "confidence" => 80, "source" => "네이버 플레이스", "quote" => "강남구 역삼동 사무실" },
        { "label" => "서울 마포구", "confidence" => 45, "source" => "인스타그램", "quote" => "마포구 합정동 스튜디오" },
      ],
      "sns_links" => [
        { "platform" => "instagram", "url" => "https://instagram.com/#{email_local}", "handle" => "@#{email_local}", "confidence" => 88 },
        { "platform" => "youtube", "url" => "https://youtube.com/@#{email_local}", "handle" => "@#{email_local}", "confidence" => 75 },
        { "platform" => "blog", "url" => "https://blog.naver.com/#{email_local}", "handle" => "blog.naver.com/#{email_local}", "confidence" => 68 },
        { "platform" => "threads", "url" => "https://threads.net/@#{email_local}", "handle" => "@#{email_local}", "confidence" => 52 },
      ],
      "bio_draft" => "저는 #{name.presence || '한 사람'}입니다. 스마트폰 하나로 새로운 일을 시작하려는 사람을 돕습니다. 30년 현장에서 배운 것을, 지금 필요한 언어로 전합니다.",
      "avatars" => [
        { "source" => "gravatar", "url" => nil, "label" => "Gravatar" },
        { "source" => "instagram", "url" => nil, "label" => "인스타그램 대표 사진" },
        { "source" => "blog", "url" => nil, "label" => "블로그 프로필" },
        { "source" => "initials", "url" => nil, "label" => "이니셜로 만들기" },
      ],
    }
  end

  def mock_bio_variations
    name = current_member.name.to_s.presence || "한 사람"
    [
      "저는 #{name}입니다. 스마트폰 하나로 새로운 일을 시작하려는 사람을 돕습니다. 30년 현장에서 배운 것을, 지금 필요한 언어로 전합니다.",
      "#{name} — 4050을 위한 스마트폰 창업 코치. 강의가 아니라 실행을 만듭니다. 작은 기술이 큰 전환이 되도록.",
      "흩어진 경험을 하나의 주소로 모읍니다. #{name}의 일은, 설명보다 증거입니다. 수업 후기 300건, 첫 달 매출 낸 수강생 42명.",
    ]
  end

  # finish 시점에 probe 결과를 Member에 반영.
  def apply_probe_to_member!(probe, _consents)
    payloads = probe.step_payloads.is_a?(Hash) ? probe.step_payloads : {}

    bio_payload     = payloads["s4"] || {}
    profession_p    = payloads["s2"] || {}
    sns_p           = payloads["s3"] || {}
    avatar_p        = payloads["s5"] || {}

    attrs = {}
    attrs[:bio] = bio_payload["bio"] if bio_payload["bio"].present?
    attrs[:profession] = profession_p["profession"] if profession_p["profession"].present?
    attrs[:region] = profession_p["region"] if current_member.respond_to?(:region) && profession_p["region"].present?

    if sns_p["links"].is_a?(Array)
      current_member.social_links = JSON.generate(sns_p["links"]) if current_member.respond_to?(:social_links=)
    end

    if avatar_p["url"].present? && current_member.respond_to?(:profile_image=)
      attrs[:profile_image] = avatar_p["url"]
    end

    attrs[:identity_probe_consent_at] = Time.current if current_member.respond_to?(:identity_probe_consent_at=)

    current_member.update(attrs) if attrs.any?
  rescue => e
    Rails.logger.error("[IdentityProbe#apply] #{e.class}: #{e.message}")
  end
end
