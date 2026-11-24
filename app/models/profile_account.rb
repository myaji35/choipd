class ProfileAccount < ApplicationRecord
  PLATFORMS = { "naver_people" => "네이버 인물정보", "linkedin" => "LinkedIn" }.freeze
  SESSION_STATUSES = { "logged_in" => "로그인됨", "logged_out" => "로그인 필요", "error" => "오류", "unknown" => "미점검" }.freeze

  belongs_to :member, optional: true
  has_many :profile_snapshots, dependent: :destroy
  has_many :linkedin_invitation_actions, dependent: :destroy
  has_many :linkedin_newsletter_drafts, dependent: :destroy

  validates :platform, inclusion: { in: PLATFORMS.keys }
  validates :session_status, inclusion: { in: SESSION_STATUSES.keys }
  validates :display_name, presence: true
  validates :external_id, uniqueness: { scope: [ :tenant_id, :platform ] }, allow_blank: true

  scope :active, -> { where(is_active: true) }
  scope :for_platform, ->(platform) { where(platform: platform) }

  def platform_label = PLATFORMS[platform]
  def session_status_label = SESSION_STATUSES[session_status]
  def latest_snapshot = profile_snapshots.recent.first

  def search_query_list
    normalize_search_queries(JSON.parse(search_queries.to_s))
  rescue JSON::ParserError
    []
  end

  def search_query_list=(queries)
    self.search_queries = normalize_search_queries(queries).presence&.to_json
  end

  private

  def normalize_search_queries(queries)
    return [] unless queries.is_a?(Array)

    queries.grep(String).map { |query| query.squish.first(50).strip }.reject(&:empty?).uniq.first(10)
  end
end
