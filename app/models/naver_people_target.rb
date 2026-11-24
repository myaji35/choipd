class NaverPeopleTarget < ApplicationRecord
  STATUSES = %w[draft approved].freeze
  FIELDS = {
    "ename" => "영문명", "jobs" => "직업", "offices" => "소속", "careers" => "경력",
    "schools" => "학력", "prizes" => "수상", "licenses" => "자격증", "sites" => "사이트"
  }.freeze

  belongs_to :profile_account

  validates :status, inclusion: { in: STATUSES }
  validate :validate_sites
  before_save :reset_approval_if_values_changed

  def values
    parse_values(data)
  end

  def values=(input)
    cleaned = FIELDS.keys.index_with do |field|
      value = input[field]
      if field == "ename"
        value.to_s.squish.first(100).strip
      else
        lines = value.is_a?(String) ? value.lines : Array(value)
        lines.grep(String).map { |line| line.squish.first(200).strip }.compact_blank.uniq.first(30)
      end
    end.compact_blank
    self.data = cleaned.to_json
  end

  def self.http_url?(value)
    return false unless value.is_a?(String)

    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    false
  end

  def approved_current?(digest)
    status == "approved" && approved_draft_digest.present? && approved_draft_digest == digest
  end

  def approval_stale?(diff)
    status == "approved" && diff.items.any? && !approved_current?(diff.digest)
  end

  def approval_label(diff)
    return "초안" unless status == "approved"
    return "네이버에 모두 반영됨" if diff.items.empty?

    approval_stale?(diff) ? "다시 승인 필요" : "승인됨"
  end

  def reset_approval
    assign_attributes(status: "draft", approved_at: nil, approved_draft_digest: nil)
  end

  private

  def parse_values(raw)
    parsed = JSON.parse(raw.to_s)
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end

  def reset_approval_if_values_changed
    reset_approval if will_save_change_to_data? && values != parse_values(data_in_database)
  end

  def validate_sites
    Array(values["sites"]).each do |url|
      errors.add(:base, "사이트 주소는 http 또는 https 주소여야 합니다. (#{url})") unless self.class.http_url?(url)
    end
  end
end
