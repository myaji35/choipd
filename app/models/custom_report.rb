class CustomReport < ApplicationRecord
  TYPES = %w[table chart dashboard export].freeze
  CHART_TYPES = %w[line bar pie area scatter heatmap].freeze

  validates :name, :report_type, :data_source, :columns, :created_by, presence: true
  validates :report_type, inclusion: { in: TYPES }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :public_visible, -> { where(is_public: true) }
end
