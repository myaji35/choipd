class SnsAccount < ApplicationRecord
  belongs_to :member, optional: true
  has_many :sns_scheduled_posts, dependent: :destroy

  encrypts :access_token_encrypted

  PLATFORMS = %w[facebook instagram twitter linkedin youtube].freeze

  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :account_name, presence: true

  scope :active, -> { where(is_active: true) }
  scope :for_member, ->(m) { where(member_id: m.id) }

  def access_token
    access_token_encrypted
  end

  def access_token=(value)
    self.access_token_encrypted = value
  end

  def platform_label
    platform.capitalize
  end
end
