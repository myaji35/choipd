class FaqKnowledgeBase < ApplicationRecord
  CATEGORIES = %w[general distributor payment resource technical].freeze

  validates :category, :question, :answer, :keywords, :created_by, presence: true
  validates :category, inclusion: { in: CATEGORIES }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :active, -> { where(is_active: true) }
  scope :sorted, -> { order(priority: :desc, match_count: :desc) }
  scope :by_category, ->(c) { where(category: c) if c.present? }

  def keywords_list
    JSON.parse(keywords || "[]") rescue []
  end

  def helpful_rate
    total = helpful_count + not_helpful_count
    return 0 if total.zero?
    (helpful_count.to_f / total * 100).round(1)
  end
end
