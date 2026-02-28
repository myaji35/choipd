class KanbanTask < ApplicationRecord
  belongs_to :kanban_column

  PRIORITIES = %w[low medium high urgent].freeze

  validates :title, presence: true
  validates :priority, inclusion: { in: PRIORITIES }, allow_blank: true

  scope :by_priority, ->(p) { where(priority: p) }
  scope :ordered, -> { order(:position) }
  scope :overdue, -> { where("due_date < ?", Date.today).where.not(priority: nil) }

  def labels_array
    return [] if labels.blank?
    JSON.parse(labels)
  rescue JSON::ParserError
    []
  end

  def labels_array=(arr)
    self.labels = arr.to_json
  end
end
