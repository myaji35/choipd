class KakaoMessage < ApplicationRecord
  belongs_to :kakao_channel
  has_many :kakao_alerts, dependent: :destroy

  KINDS = %w[question statement complaint].freeze
  TYPES = %w[text image file link].freeze

  validates :sender_kakao_id, :body, :received_at, presence: true

  scope :recent, -> { order(received_at: :desc) }
  scope :unanswered, -> { where(replied: false) }
  scope :urgent, -> { where("urgency_score >= ?", 70) }
  scope :for_date, ->(d) { where(received_at: d.beginning_of_day..d.end_of_day) }
  scope :keep_only, -> { where("received_at > ?", 7.days.ago).where(purged: false) }

  def reply!
    update!(replied: true, replied_at: Time.current)
  end

  # 7일 후 원문 파기 (PII 보호)
  def self.purge_old!
    where("received_at <= ?", 7.days.ago).where(purged: false).find_each do |m|
      m.update!(body: "[purged]", purged: true)
    end
  end
end
