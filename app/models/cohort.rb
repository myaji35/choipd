class Cohort < ApplicationRecord
  has_many :cohort_users, dependent: :destroy

  TYPES = %w[acquisition behavior demographic custom].freeze

  validates :name, :cohort_type, :start_date, :end_date, :criteria, :created_by, presence: true
  validates :cohort_type, inclusion: { in: TYPES }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :recent, -> { order(created_at: :desc) }

  def criteria_hash
    JSON.parse(criteria || "{}") rescue {}
  end

  def metrics_hash
    JSON.parse(metrics || "{}") rescue {}
  end
end
