class KanbanColumn < ApplicationRecord
  belongs_to :kanban_project
  has_many :kanban_tasks, dependent: :destroy

  validates :title, presence: true
  validates :sort_order, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:sort_order, :id) }
end
