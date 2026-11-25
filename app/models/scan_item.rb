class ScanItem < ApplicationRecord
  STATUSES = %w[pending processing processed needs_review failed].freeze
  CATEGORIES = %w[business_card receipt document].freeze

  belongs_to :member

  validates :source_file_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true

  serialize :extracted_json, coder: JSON, type: Hash

  def extracted
    extracted_json
  end

  def extracted=(value)
    self.extracted_json = value
  end
end
