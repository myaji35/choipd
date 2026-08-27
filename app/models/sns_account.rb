class SnsAccount < ApplicationRecord
  belongs_to :member, optional: true
  has_many :sns_scheduled_posts, dependent: :destroy
  has_many :sns_follower_snapshots, dependent: :destroy

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

  def latest_follower_snapshot
    if sns_follower_snapshots.loaded?
      sns_follower_snapshots.max_by(&:captured_at)
    else
      sns_follower_snapshots.recent.first
    end
  end

  def follower_count
    latest_follower_snapshot&.follower_count
  end

  def follower_delta
    snapshots = if sns_follower_snapshots.loaded?
      sns_follower_snapshots.sort_by(&:captured_at).reverse.first(2)
    else
      sns_follower_snapshots.recent.limit(2).to_a
    end
    return if snapshots.size < 2

    snapshots.first.follower_count - snapshots.second.follower_count
  end
end
