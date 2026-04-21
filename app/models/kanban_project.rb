class KanbanProject < ApplicationRecord
  has_many :kanban_columns, dependent: :destroy
  has_many :kanban_tasks, through: :kanban_columns

  validates :title, presence: true

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(is_archived: false) }
  scope :sorted, -> { order(:sort_order, :created_at) }
end
