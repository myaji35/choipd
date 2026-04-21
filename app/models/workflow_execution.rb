class WorkflowExecution < ApplicationRecord
  belongs_to :workflow

  STATUSES = %w[pending running completed failed cancelled].freeze
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :failed, -> { where(status: "failed") }

  def steps_list
    JSON.parse(steps || "[]") rescue []
  end
end
