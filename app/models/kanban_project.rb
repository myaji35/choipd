class KanbanProject < ApplicationRecord
  has_many :kanban_columns, dependent: :destroy
  has_many :kanban_tasks, through: :kanban_columns

  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
