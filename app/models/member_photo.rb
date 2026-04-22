class MemberPhoto < ApplicationRecord
  belongs_to :member
  has_one_attached :image

  CATEGORIES = %w[daily workshop product press people].freeze

  # 핸드폰이 만드는 이미지 포맷 전반 (iOS HEIC·Android JPEG·스크린샷 PNG·최신 AVIF 포함)
  IMAGE_TYPES = %w[
    image/jpeg image/jpg image/pjpeg
    image/png
    image/webp
    image/heic image/heif image/heic-sequence image/heif-sequence
    image/gif
    image/avif
    image/bmp
  ].freeze

  # 핸드폰 영상 포맷 (iPhone .mov, Android .mp4/.3gp, 녹화 영상)
  VIDEO_TYPES = %w[
    video/mp4
    video/quicktime
    video/x-m4v
    video/3gpp
    video/webm
  ].freeze

  ALLOWED_TYPES = (IMAGE_TYPES + VIDEO_TYPES).freeze

  IMAGE_MAX_BYTES = 25 * 1024 * 1024  # 25MB — HEIC burst·4K 사진
  VIDEO_MAX_BYTES = 100 * 1024 * 1024 # 100MB — 짧은 영상·Live Photo

  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validate :image_attached
  validate :image_type
  validate :image_size

  before_save :ensure_uploaded_at

  scope :ordered,      -> { order(sort_order: :asc, uploaded_at: :desc, id: :desc) }
  scope :for_category, ->(cat) { where(category: cat) if cat.present? }

  def video?
    return false unless image.attached?
    VIDEO_TYPES.include?(image.content_type)
  end

  def image?
    return false unless image.attached?
    IMAGE_TYPES.include?(image.content_type)
  end

  def thumbnail_url
    return nil unless image.attached?
    # 비디오는 썸네일 variant를 만들지 않고 포스터 없이 blob URL 반환
    return Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true) if video?

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
    return if ALLOWED_TYPES.include?(image.content_type)
    errors.add(:image, "지원하지 않는 형식입니다 (#{image.content_type})")
  end

  def image_size
    return unless image.attached?
    limit = video? ? VIDEO_MAX_BYTES : IMAGE_MAX_BYTES
    return if image.byte_size <= limit
    kind = video? ? "영상" : "이미지"
    mb   = (limit / 1024.0 / 1024.0).round
    errors.add(:image, "#{kind} 파일은 #{mb}MB 이하여야 합니다")
  end

  def ensure_uploaded_at
    self.uploaded_at ||= Time.current
  end
end
