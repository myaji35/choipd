class ContentQualityScore < ApplicationRecord
  validates :content_type, :content_id, :overall_score, :analyzed_by, presence: true
  validates :overall_score, inclusion: { in: 0..100 }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :recent, -> { order(analyzed_at: :desc) }

  def keyword_density_hash
    JSON.parse(keyword_density || "{}") rescue {}
  end

  def suggestions_list
    JSON.parse(suggestions || "[]") rescue []
  end
end
