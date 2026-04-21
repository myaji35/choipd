class RfmSegment < ApplicationRecord
  USER_TYPES = %w[distributor lead].freeze
  SEGMENTS = ["Champions", "Loyal", "Potential", "New", "At Risk", "Cant Lose", "Hibernating", "Lost"].freeze

  validates :user_id, :user_type, :recency_score, :frequency_score, :monetary_score, :rfm_segment, presence: true
  validates :recency_score, :frequency_score, :monetary_score, inclusion: { in: 1..5 }
  validates :user_type, inclusion: { in: USER_TYPES }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :by_segment, ->(s) { where(rfm_segment: s) if s.present? }

  # RFM 점수 → 세그먼트 분류
  def self.classify(r:, f:, m:)
    case
    when r >= 4 && f >= 4 && m >= 4 then "Champions"
    when r >= 3 && f >= 3 && m >= 3 then "Loyal"
    when r >= 4 && f <= 2 then "New"
    when r <= 2 && f >= 4 then "At Risk"
    when r <= 2 && f <= 2 && m <= 2 then "Lost"
    when r <= 2 && m >= 4 then "Cant Lose"
    when r >= 3 && f <= 2 then "Potential"
    else "Hibernating"
    end
  end

  def total_score
    recency_score + frequency_score + monetary_score
  end
end
