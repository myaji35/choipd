class SnsFollowerSnapshot < ApplicationRecord
  belongs_to :sns_account

  SOURCES = %w[manual api].freeze

  validates :follower_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :source, inclusion: { in: SOURCES }
  validates :captured_at, presence: true

  scope :recent, -> { order(captured_at: :desc) }
end
