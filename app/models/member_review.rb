class MemberReview < ApplicationRecord
  belongs_to :member

  STATUSES = %w[new triaged responded archived].freeze
  SOURCES = %w[public_form admin_submitted].freeze

  validates :reviewer_name, presence: true
  validates :rating, inclusion: { in: 1..5 }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :public_visible, -> { where(status: %w[triaged responded]) }
  scope :triaged, -> { where(status: %w[triaged responded]) }
end
