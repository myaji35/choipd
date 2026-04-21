class KakaoAlert < ApplicationRecord
  belongs_to :kakao_channel
  belongs_to :kakao_message

  TYPES = %w[urgent_keyword unanswered_long complaint].freeze

  validates :alert_type, inclusion: { in: TYPES }

  scope :unread, -> { where(acknowledged: false) }
  scope :recent, -> { order(created_at: :desc) }

  def ack!
    update!(acknowledged: true, acknowledged_at: Time.current)
  end
end
