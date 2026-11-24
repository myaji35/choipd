class BrandChannel < ApplicationRecord
  PLATFORMS = {
    "naver_blog" => "네이버 블로그",
    "naver_people" => "네이버 인물정보",
    "linkedin_profile" => "링크드인 프로필",
    "linkedin_page" => "링크드인 페이지",
    "facebook_page" => "페이스북 페이지",
    "instagram" => "인스타그램",
    "threads" => "스레드",
    "youtube" => "유튜브",
    "kakao_channel" => "카카오톡 채널",
    "other" => "기타"
  }.freeze

  CONNECTION_METHODS = {
    "oauth" => "공식 연동",
    "ego_session" => "ego 브라우저 로그인",
    "manual" => "수동"
  }.freeze

  SESSION_STATUSES = {
    "connected" => "연결됨",
    "logged_out" => "로그인 필요",
    "error" => "오류",
    "unknown" => "미점검"
  }.freeze

  DEFAULT_CONNECTION_METHODS = {
    "naver_blog" => "ego_session",
    "naver_people" => "ego_session",
    "linkedin_profile" => "ego_session",
    "linkedin_page" => "oauth",
    "facebook_page" => "oauth",
    "instagram" => "oauth",
    "threads" => "oauth"
  }.freeze

  belongs_to :brand
  belongs_to :sns_account, optional: true
  belongs_to :profile_account, optional: true

  normalizes :credential_ref, :profile_url, with: ->(value) { value.presence }

  before_validation :set_default_connection_method, on: :create
  before_validation :sync_tenant_id

  validates :platform, inclusion: { in: PLATFORMS.keys, message: "채널 종류를 선택해 주세요." }
  validates :connection_method, inclusion: { in: CONNECTION_METHODS.keys, message: "지원하는 연결 방식을 선택해 주세요." }
  validates :session_status, inclusion: { in: SESSION_STATUSES.keys, message: "지원하는 연결 상태를 선택해 주세요." }
  validates :credential_ref,
    format: { with: /\A[a-zA-Z0-9_.-]+\z/, message: "보관 위치 이름표에는 영문, 숫자, 하이픈, 밑줄, 마침표만 사용할 수 있습니다." },
    length: { maximum: 64, message: "보관 위치 이름표는 64자 이하여야 합니다." }, allow_nil: true
  validate :validate_profile_url
  validate :validate_account_ownership
  validate :validate_instagram_connection_method

  def delegated?
    delegation_consent_at.present?
  end

  private

  def set_default_connection_method
    self.connection_method = DEFAULT_CONNECTION_METHODS.fetch(platform, "manual") if connection_method.blank?
  end

  def sync_tenant_id
    self.tenant_id = brand.tenant_id if brand
  end

  def validate_account_ownership
    return unless brand

    if sns_account_id && !SnsAccount.exists?(id: sns_account_id, member_id: brand.member_id)
      errors.add(:sns_account, "브랜드와 같은 회원의 SNS 계정을 선택해 주세요.")
    end
    if profile_account_id && !ProfileAccount.exists?(id: profile_account_id, member_id: brand.member_id)
      errors.add(:profile_account, "브랜드와 같은 회원의 프로필 계정을 선택해 주세요.")
    end
  end

  def validate_instagram_connection_method
    return unless platform == "instagram" && connection_method == "ego_session"

    errors.add(:connection_method, "인스타그램은 계정 잠김 위험으로 ego 로그인 대신 공식 연동을 사용합니다")
  end

  def validate_profile_url
    return if profile_url.nil?

    uri = URI.parse(profile_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?

    errors.add(:profile_url, "채널 주소는 http 또는 https 주소여야 합니다.")
  rescue URI::InvalidURIError
    errors.add(:profile_url, "채널 주소는 http 또는 https 주소여야 합니다.")
  end
end
