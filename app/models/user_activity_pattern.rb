class UserActivityPattern < ApplicationRecord
  USER_TYPES = %w[distributor pd customer].freeze
  CHURN_LEVELS = %w[low medium high].freeze

  validates :user_id, :user_type, presence: true
  validates :user_id, uniqueness: true
  validates :churn_risk, inclusion: { in: CHURN_LEVELS }, allow_nil: true

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :high_churn, -> { where(churn_risk: "high") }
  scope :engaged, -> { where("engagement_score >= 70") }

  def preferred_categories_list
    JSON.parse(preferred_categories || "[]") rescue []
  end

  def active_hours_list
    JSON.parse(active_hours || "[]") rescue []
  end
end
