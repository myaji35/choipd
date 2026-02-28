class Invoice < ApplicationRecord
  belongs_to :distributor
  belongs_to :payment

  enum :status, { draft: "draft", issued: "issued", paid: "paid", overdue: "overdue" }, prefix: true

  validates :amount, presence: true, numericality: { greater_than: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :issued, -> { where(status: "issued") }
end
