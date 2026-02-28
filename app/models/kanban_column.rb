class KanbanColumn < ApplicationRecord
  belongs_to :kanban_project
  has_many :kanban_tasks, dependent: :destroy

  validates :title, presence: true
  validates :position, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:position) }
end
