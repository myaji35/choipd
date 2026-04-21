class AnalyticsEvent < ApplicationRecord
  USER_TYPES = %w[admin pd distributor lead anonymous].freeze
  DEVICE_TYPES = %w[desktop mobile tablet].freeze

  validates :event_name, :event_category, presence: true

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :recent, -> { order(created_at: :desc) }
  scope :in_period, ->(from, to) { where(created_at: from..to) }
  scope :by_event, ->(name) { where(event_name: name) if name.present? }
  scope :by_category, ->(c) { where(event_category: c) if c.present? }

  # 간단 트래킹 헬퍼
  def self.track(event_name:, event_category: "engagement", user_id: nil, user_type: "anonymous", **attrs)
    create!(
      event_name: event_name,
      event_category: event_category,
      user_id: user_id,
      user_type: user_type,
      tenant_id: 1,
      **attrs
    )
  rescue StandardError => e
    Rails.logger.error "[AnalyticsEvent.track] #{e.message}"
    nil
  end

  def metadata_hash
    JSON.parse(metadata || "{}") rescue {}
  end
end
