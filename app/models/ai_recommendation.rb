class AiRecommendation < ApplicationRecord
  USER_TYPES = %w[distributor pd customer].freeze
  TYPES = %w[resource course post distributor].freeze

  validates :user_id, :recommendation_type, :target_id, :score, presence: true
  validates :score, inclusion: { in: 0..100 }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(uid) { where(user_id: uid) }
  scope :clicked, -> { where(clicked: true) }

  def reason_list
    JSON.parse(reason || "[]") rescue []
  end

  def click!
    update!(clicked: true, clicked_at: Time.current)
  end
end
