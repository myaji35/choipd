class SnsScheduledPost < ApplicationRecord
  belongs_to :member, optional: true
  belongs_to :sns_account, optional: true
  belongs_to :profile_account, optional: true
  has_many :sns_post_histories, dependent: :destroy

  enum :status, { draft: "draft", scheduled: "scheduled", publishing: "publishing", published: "published", failed: "failed" }, prefix: true

  validates :message, presence: true
  validates :message, length: { maximum: 3000 }, if: :linkedin_share?

  before_save :clear_linkedin_approval, if: :linkedin_share?
  validates :platform, presence: true
  validates :scheduled_at, presence: true

  validate :validate_brand_channel_consent, if: -> { new_record? || will_save_change_to_sns_account_id? }

  scope :upcoming, -> { where(status: "scheduled").where("scheduled_at > ?", Time.current).order(:scheduled_at) }
  scope :due, -> { where(status: "scheduled").where("scheduled_at <= ?", Time.current) }
  scope :linkedin_shares, -> { where(platform: "linkedin").where.not(profile_account_id: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def linkedin_share? = platform == "linkedin" && profile_account_id.present?
  def publishing_locked? = status_publishing? || status_published? || published_at.present?

  private

  def clear_linkedin_approval
    return unless approved_at && (will_save_change_to_message? || will_save_change_to_scheduled_at?)

    self.approved_at = nil
    self.status = "draft"
  end


  def validate_brand_channel_consent
    return unless sns_account_id

    owner_id = member_id || sns_account&.member_id
    return unless owner_id

    channels = BrandChannel.joins(:brand).where(brands: { member_id: owner_id }, sns_account_id: sns_account_id)
    if channels.exists?(delegation_consent_at: nil)
      errors.add(:base, "브랜드 채널의 운영 위탁 동의가 필요합니다.")
    end
  end
end
