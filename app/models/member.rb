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
end
