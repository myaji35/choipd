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
  has_many :member_gap_reports,     dependent: :destroy

  STATUSES = %w[pending_approval approved rejected suspended].freeze
  IMPD_STATUSES = %w[none in_progress completed rejected].freeze
  BUSINESS_TYPES = %w[individual company organization].freeze
  PROFESSIONS = %w[insurance_agent realtor educator author shopowner freelancer custom].freeze

  validates :name, :email, :slug, presence: true
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

  def pending?
    status == "pending_approval"
  end
end
