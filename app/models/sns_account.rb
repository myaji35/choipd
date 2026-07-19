class SnsAccount < ApplicationRecord
  belongs_to :member, optional: true
  has_many :sns_scheduled_posts, dependent: :destroy

  PLATFORMS = %w[facebook instagram twitter linkedin youtube].freeze

  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :account_name, presence: true

  scope :active, -> { where(is_active: true) }
  scope :for_member, ->(m) { where(member_id: m.id) }

  def platform_label
    platform.capitalize
  end
end
