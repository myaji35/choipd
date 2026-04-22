class Member < ApplicationRecord
  include SlugValidation

  has_secure_password validations: false

  has_many :member_portfolio_items, dependent: :destroy
  has_many :member_services,        dependent: :destroy
  has_many :member_posts,           dependent: :destroy
  has_many :member_inquiries,       dependent: :destroy
  has_many :member_reviews,         dependent: :destroy
  has_many :member_bookings,        dependent: :destroy
  has_many :member_skills,          dependent: :destroy
  has_many :skills, through: :member_skills
  has_many :member_documents,       dependent: :destroy
  has_many :member_photos,          dependent: :destroy
  has_many :member_gap_reports,     dependent: :destroy

  STATUSES = %w[pending_approval approved rejected suspended].freeze
  IMPD_STATUSES = %w[none in_progress completed rejected].freeze
  BUSINESS_TYPES = %w[individual company organization].freeze
  PROFESSIONS = %w[insurance_agent realtor educator author shopowner freelancer custom].freeze

  validates :name, :email, :slug, presence: true
  validates :slug, uniqueness: { case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }
  validates :impd_status, inclusion: { in: IMPD_STATUSES }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(s) { where(status: s) if s.present? }
  scope :by_impd, ->(s) { where(impd_status: s) if s.present? }
  scope :by_profession, ->(p) { where(profession: p) if p.present? }
  scope :search, ->(q) { where("name LIKE ? OR email LIKE ? OR slug LIKE ?", "%#{q}%", "%#{q}%", "%#{q}%") if q.present? }

  def display_url
    "/#{slug}"
  end

  def social
    JSON.parse(social_links || "{}") rescue {}
  end

  def modules
    JSON.parse(enabled_modules || "[]") rescue []
  end

  def theme
    JSON.parse(theme_config || "{}") rescue {}
  end

  def impd_completed?
    impd_status == "completed"
  end

  def approved?
    status == "approved"
  end

  # ── Townin 파트너 계층 ──────────────────────────
  # status=approved → 일반 회원 (소소한 활동, 본인 페이지 편집 가능)
  # partner_status=active → Townin 파트너 (공개 페이지에 파트너 활동 섹션 자동 노출)
  PARTNER_STATUSES = %w[none pending active suspended].freeze

  def partner_active?
    partner_status == "active"
  end

  def partner_pending?
    partner_status == "pending"
  end

  def partner_connected?
    towningraph_user_id.present?
  end

  def partner_display_role
    return nil unless partner_active?
    townin_role.presence || "파트너"
  end

  def promote_to_partner!(notes: nil)
    update!(
      partner_status: "active",
      partner_promoted_at: Time.current,
      partner_notes: notes.presence,
    )
  end

  def demote_from_partner!(reason: nil)
    update!(
      partner_status: "suspended",
      partner_notes: [ partner_notes, "[suspended #{Time.current.to_date}] #{reason}" ].compact.join("\n"),
    )
  end

  # ── OAuth ──────────────────────────────────────
  OAUTH_PROVIDERS = %w[google_oauth2].freeze

  def oauth_connected?
    provider.present? && uid.present?
  end

  # OmniAuth 콜백 → Member 조회 또는 신규 생성.
  # 정책: 신규 가입 허용. provider+uid 매칭 없으면 email 매칭 시도, 없으면 신규 Member 생성.
  def self.from_omniauth(auth)
    return nil unless auth && auth.provider && auth.uid

    # 1) provider+uid로 기존 회원 찾기
    existing = find_by(provider: auth.provider, uid: auth.uid.to_s)
    return existing if existing

    # 2) email로 기존 회원 찾아 연결
    info  = auth.info || {}
    email = info.email.to_s.downcase.presence
    if email
      member = find_by("LOWER(email) = ?", email)
      if member
        member.update(
          provider: auth.provider,
          uid: auth.uid.to_s,
          oauth_email_verified: info.email_verified ? 1 : 0,
          oauth_connected_at: Time.current,
          oauth_raw: auth.extra&.raw_info&.to_json,
        )
        return member
      end
    end

    # 3) 신규 Member 생성
    create_from_oauth!(auth)
  end

  # 신규 Member를 OAuth 콜백으로부터 생성.
  # status=pending_approval (대표님이 /admin에서 승인 필요).
  def self.create_from_oauth!(auth)
    info  = auth.info || {}
    email = info.email.to_s.downcase
    name  = info.name.presence || info.first_name.presence || email.split("@").first
    # slug: name 기반 + 충돌 시 suffix
    base_slug = name.to_s.downcase.gsub(/[^a-z0-9\-]/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "").presence || "m-#{SecureRandom.hex(3)}"
    slug = base_slug
    i = 0
    while where(slug: slug).exists?
      i += 1
      slug = "#{base_slug}-#{i}"
    end

    create!(
      tenant_id: 1,
      name: name,
      email: email.presence || "oauth-#{auth.uid}@impd.placeholder",
      slug: slug,
      profile_image: info.image,
      provider: auth.provider,
      uid: auth.uid.to_s,
      oauth_email_verified: info.email_verified ? 1 : 0,
      oauth_connected_at: Time.current,
      oauth_raw: auth.extra&.raw_info&.to_json,
      business_type: "individual",
      profession: "custom",
      status: "pending_approval",
      impd_status: "none",
    )
  end

  def pending?
    status == "pending_approval"
  end

  # ── Townin 활동 스냅샷 ─────────────────────────
  # 공개 페이지에 "지금 진짜 일하고 있다"는 증거를 노출한다.
  # 숫자 뽐내기가 아니라 "동료가 숨쉬고 있다"는 리듬이 목적.
  # 출처: Townin API (추후) 또는 관리자가 직접 입력.
  DISPLAY_MODES = %w[revenue_exact revenue_range revenue_delta revenue_hidden].freeze

  def stats
    @stats ||= JSON.parse(townin_stats_json || "{}") rescue {}
  end

  def stats_fresh?
    stats.any? && stats_synced_at.present? && stats_synced_at > 30.days.ago
  end

  # 부러움 유발의 핵심: "지금 살아 움직이고 있다"는 신호.
  # 활동 기록이 있고 최근 7일 내 업데이트됐으면 LIVE 배지.
  def activity_live?
    last = stats["last_activity_at"]
    return false if last.blank?
    Time.parse(last.to_s) > 7.days.ago rescue false
  end

  # 매출 노출은 본인이 고른 모드 따라. 기본값은 범위.
  def revenue_label
    return nil unless stats["monthly_revenue"].present?
    mode = stats_display_mode.presence || "revenue_range"
    value = stats["monthly_revenue"].to_i
    case mode
    when "revenue_hidden"  then nil
    when "revenue_exact"   then "₩#{value.to_s(:delimited)}"
    when "revenue_range"   then revenue_range_label(value)
    when "revenue_delta"
      delta = stats["monthly_revenue_delta_pct"].to_f
      delta.zero? ? "이번달 꾸준히" : "전월 대비 #{delta.positive? ? '+' : ''}#{delta.round}%"
    end
  end

  def revenue_range_label(value)
    return "이번달 시작" if value < 100_000
    return "₩10만원대" if value < 1_000_000
    return "₩#{(value / 100_000).floor * 10}만원대" if value < 10_000_000
    "₩#{(value / 1_000_000).floor}백만원대"
  end
  private :revenue_range_label
end
