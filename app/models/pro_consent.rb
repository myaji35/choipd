class ProConsent < ApplicationRecord
  TYPES = %w[kakao_data_processing customer_disclosure tos socialdoctors_exposure townin_local_ads].freeze

  SOCIALDOCTORS_EXPOSURE_TEXT = "[선택] SocialDoctors 브랜드 노출 동의\n내 프로필(이름, 소개, 직군, 지역, 프로필/커버 이미지, SNS 링크)이\nSocialDoctors 마켓플레이스에 노출되어 홍보에 활용되는 것에 동의합니다.\n· 노출 정보에 연락처(이메일·전화번호)는 포함되지 않습니다.\n· 언제든 이 화면에서 철회할 수 있으며, 철회 시 노출이 중단됩니다.".freeze
  TOWNIN_LOCAL_ADS_TEXT = "[선택] Townin 지역 광고 동의\n내 브랜드 정보(이름, 소개, 직군, 지역, 이미지)로 SocialDoctors가 Townin 디지털 전단지를 만들고, 내 Townin 광고주 계정 명의로 게시 신청하는 것에 동의합니다.\n· 전단지는 Townin 지역 파트너의 승인 후에만 노출되며, 광고비는 내 Townin 광고 포인트에서 읽은 사람 1명당 50원씩 차감됩니다.\n· 언제든 이 화면에서 철회할 수 있으며, 철회 시 새 전단지 게시가 중단됩니다.".freeze
  BRAND_CONSENT_TEXTS = { "socialdoctors_exposure" => SOCIALDOCTORS_EXPOSURE_TEXT, "townin_local_ads" => TOWNIN_LOCAL_ADS_TEXT }.freeze

  validates :owner_id, :consent_type, presence: true
  validates :consent_type, inclusion: { in: TYPES }

  scope :for_owner, ->(oid) { where(owner_id: oid) }
  scope :granted, -> { where(consented: true).where(revoked_at: nil) }

  def revoke!
    update!(revoked_at: Time.current, consented: false)
  end

  def self.current_for(owner_id, type)
    granted.for_owner(owner_id).where(consent_type: type).order(consented_at: :desc, id: :desc).first
  end

  def self.has_consent?(owner_id:, type:)
    granted.for_owner(owner_id).where(consent_type: type).exists?
  end
end
