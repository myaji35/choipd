class SnsScheduledPost < ApplicationRecord
  belongs_to :sns_account, optional: true
  has_many :sns_post_histories, dependent: :destroy

  enum :status, { draft: "draft", scheduled: "scheduled", published: "published", failed: "failed" }, prefix: true

  validates :message, presence: true
  validates :platform, presence: true
  validates :scheduled_at, presence: true

  scope :upcoming, -> { where(status: "scheduled").where("scheduled_at > ?", Time.current).order(:scheduled_at) }
  scope :recent, -> { order(created_at: :desc) }
end
