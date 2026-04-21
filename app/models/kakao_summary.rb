class KakaoSummary < ApplicationRecord
  belongs_to :kakao_channel

  validates :summary_date, :must_reply_lines, :daily_summary_lines, :generated_at, presence: true

  scope :recent, -> { order(summary_date: :desc) }

  def must_reply
    JSON.parse(must_reply_lines || "[]") rescue []
  end

  def daily
    JSON.parse(daily_summary_lines || "[]") rescue []
  end

  def push!
    update!(pushed: true, pushed_at: Time.current)
  end
end
