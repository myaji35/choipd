class MemberPhoto < ApplicationRecord
  belongs_to :member
  has_one_attached :image

  CATEGORIES = %w[daily workshop product press people].freeze

  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validate :image_attached
  validate :image_type
  validate :image_size

  before_save :ensure_uploaded_at

  scope :ordered,      -> { order(sort_order: :asc, uploaded_at: :desc, id: :desc) }
  scope :for_category, ->(cat) { where(category: cat) if cat.present? }

  def thumbnail_url
    return nil unless image.attached?
    # 썸네일 variant — 480px 가로 기준
    Rails.application.routes.url_helpers.rails_representation_url(
      image.variant(resize_to_limit: [ 480, 480 ]),
      only_path: true,
    )
  rescue StandardError
    Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
  end

  def display_url
    return nil unless image.attached?
    Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
  end

  private

  def image_attached
    errors.add(:image, "이미지를 첨부해주세요") unless image.attached?
  end

  def image_type
    return unless image.attached?
    allowed = %w[image/jpeg image/png image/webp image/heic image/heif image/gif]
    return if allowed.include?(image.content_type)
    errors.add(:image, "지원하지 않는 형식입니다 (JPG/PNG/WebP/HEIC/GIF)")
  end

  def image_size
    return unless image.attached?
    return if image.byte_size <= 15.megabytes
    errors.add(:image, "파일은 15MB 이하여야 합니다")
  end

  def ensure_uploaded_at
    self.uploaded_at ||= Time.current
  end
end
