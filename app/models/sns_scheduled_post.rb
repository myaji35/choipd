class SnsScheduledPost < ApplicationRecord
  belongs_to :member, optional: true
  belongs_to :sns_account, optional: true
  belongs_to :profile_account, optional: true
  belongs_to :brand_channel, optional: true
  has_many :sns_post_histories, dependent: :destroy

  enum :status, { draft: "draft", scheduled: "scheduled", publishing: "publishing", published: "published", failed: "failed" }, prefix: true

  validates :message, presence: true
  validates :message, length: { maximum: 3000 }, if: :linkedin_share?

  validates :title, presence: true, length: { maximum: 100 }, if: :naver_blog_post?
  before_save :clear_linkedin_approval, if: :linkedin_share?
  before_save :clear_naver_blog_approval, if: -> { naver_blog_post? || platform_in_database == "naver_blog" }
  validates :platform, presence: true
  validates :scheduled_at, presence: true

  validate :validate_brand_channel_consent, if: -> { new_record? || will_save_change_to_sns_account_id? }

  validate :validate_naver_blog_channel

  scope :upcoming, -> { where(status: "scheduled").where("scheduled_at > ?", Time.current).order(:scheduled_at) }
  scope :due, -> { where(status: "scheduled").where("scheduled_at <= ?", Time.current) }
  scope :linkedin_shares, -> { where(platform: "linkedin").where.not(profile_account_id: nil) }
  scope :naver_blog_posts, -> { where(platform: "naver_blog").where.not(brand_channel_id: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def linkedin_share? = platform == "linkedin" && profile_account_id.present?
  def naver_blog_post? = platform == "naver_blog"
  def publishing_locked? = status_publishing? || status_published? || published_at.present?

  private

  def clear_linkedin_approval
    return unless approved_at && (will_save_change_to_message? || will_save_change_to_scheduled_at?)

    self.approved_at = nil
    self.status = "draft"
  end

  def clear_naver_blog_approval
    return unless (approved_at || approved_at_in_database) && (will_save_change_to_message? || will_save_change_to_title? ||
      will_save_change_to_scheduled_at? || will_save_change_to_brand_channel_id? ||
      will_save_change_to_platform? || will_save_change_to_member_id?)

    self.approved_at = nil
    self.status = "draft"
  end

  def validate_naver_blog_channel
    return unless brand_channel_id || brand_channel

    unless brand_channel
      errors.add(:brand_channel, :required)
      return
    end

    errors.add(:base, "브랜드 채널의 운영 위탁 동의가 필요합니다.") unless brand_channel.delegated?
    unless naver_blog_post? && brand_channel.platform == "naver_blog"
      errors.add(:brand_channel, "네이버 블로그 채널을 선택해 주세요.")
    end
    if member_id && member_id != brand_channel.brand.member_id
      errors.add(:brand_channel, "게시물과 같은 회원의 브랜드 채널을 선택해 주세요.")
    end
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
