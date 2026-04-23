# 짧은 URL 매핑.
# /s/:hash_code → target_path 리다이렉트.
# 보안: target_path 는 내부 경로만 허용 (오픈 리다이렉터 방지).
class ShortLink < ApplicationRecord
  belongs_to :member, optional: true

  validates :hash_code, presence: true, uniqueness: { case_sensitive: true },
                        format: { with: /\A[a-zA-Z0-9]+\z/ }
  validates :target_path, presence: true,
                          format: { with: %r{\A/[^\s]*\z}, message: "는 '/'로 시작하는 내부 경로여야 합니다" }

  CHARS = ([*"0".."9", *"a".."z", *"A".."Z"]).freeze
  DEFAULT_LENGTH = 8

  scope :for_member, ->(m) { where(member_id: m.id) if m }

  # 내부 경로 (회원 slug, /promo/* 등) 만 허용. 외부 URL 차단.
  def self.safe_target?(path)
    return false if path.blank?
    return false unless path.start_with?("/")
    return false if path.include?("//") # "//external.com" 방어
    true
  end

  # 충돌 회피하며 hash_code 생성. 기본 8자 base62.
  def self.generate_hash(length: DEFAULT_LENGTH)
    10.times do
      code = Array.new(length) { CHARS.sample }.join
      return code unless exists?(hash_code: code)
    end
    # 극단적 충돌 시 길이 +1
    generate_hash(length: length + 1)
  end

  # 주어진 경로/회원에 대해 short link 발급 (중복 시 기존 것 재사용).
  def self.resolve_or_create(target_path:, member: nil)
    return nil unless safe_target?(target_path)
    existing = where(target_path: target_path, member_id: member&.id).order(:created_at).first
    return existing if existing
    create!(hash_code: generate_hash, target_path: target_path, member_id: member&.id)
  end

  # 클릭 증가 (비동기 권장이나 간단한 수량은 즉시 update 허용)
  def record_click!
    update_columns(click_count: click_count + 1, last_clicked_at: Time.current)
  end
end
