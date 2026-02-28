class Payment < ApplicationRecord
  belongs_to :distributor
  has_one :invoice, dependent: :destroy

  enum :status, { pending: "pending", completed: "completed", failed: "failed", refunded: "refunded" }, prefix: true

  validates :amount, presence: true, numericality: { greater_than: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: "completed") }
end
