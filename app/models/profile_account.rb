class ProfileAccount < ApplicationRecord
  PLATFORMS = { "naver_people" => "네이버 인물정보", "linkedin" => "LinkedIn" }.freeze
  SESSION_STATUSES = { "logged_in" => "로그인됨", "logged_out" => "로그인 필요", "error" => "오류", "unknown" => "미점검" }.freeze

  belongs_to :member, optional: true
  has_many :profile_snapshots, dependent: :destroy

  validates :platform, inclusion: { in: PLATFORMS.keys }
  validates :session_status, inclusion: { in: SESSION_STATUSES.keys }
  validates :display_name, presence: true
  validates :external_id, uniqueness: { scope: [ :tenant_id, :platform ] }, allow_blank: true

  scope :active, -> { where(is_active: true) }
  scope :for_platform, ->(platform) { where(platform: platform) }

  def platform_label = PLATFORMS[platform]
  def session_status_label = SESSION_STATUSES[session_status]
  def latest_snapshot = profile_snapshots.recent.first
end
