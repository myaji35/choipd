class Notification < ApplicationRecord
  TYPES = %w[info success warning error task_assigned mention].freeze

  validates :title, presence: true

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :unread, -> { where(is_read: false) }
  scope :recent, -> { order(created_at: :desc) }

  def mark_read!
    update!(is_read: true, read_at: Time.current)
  end
end
