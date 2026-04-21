class KanbanTask < ApplicationRecord
  belongs_to :kanban_column
  belongs_to :kanban_project, optional: true, foreign_key: :project_id

  PRIORITIES = %w[low medium high urgent].freeze

  validates :title, presence: true
  validates :priority, inclusion: { in: PRIORITIES }, allow_blank: true

  before_save :sync_project_id

  scope :by_priority, ->(p) { where(priority: p) if p.present? }
  scope :ordered, -> { order(:sort_order, :id) }
  scope :overdue, -> { where("due_date < ?", Date.today).where(is_completed: false) }
  scope :completed, -> { where(is_completed: true) }
  scope :open, -> { where(is_completed: false) }

  def labels_array
    return [] if labels.blank?
    JSON.parse(labels) rescue []
  end

  def labels_array=(arr)
    self.labels = arr.to_json
  end

  def complete!
    update!(is_completed: true, completed_at: Time.current)
  end

  def reopen!
    update!(is_completed: false, completed_at: nil)
  end

  private

  def sync_project_id
    self.project_id ||= kanban_column&.kanban_project_id
  end
end
