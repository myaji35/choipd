class SnsAccount < ApplicationRecord
  has_many :sns_scheduled_posts, dependent: :destroy

  PLATFORMS = %w[facebook instagram twitter linkedin youtube].freeze

  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :account_name, presence: true

  scope :active, -> { where(is_active: true) }

  def platform_label
    platform.capitalize
  end
end
