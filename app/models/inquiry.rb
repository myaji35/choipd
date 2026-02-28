class Inquiry < ApplicationRecord
  enum :inquiry_type, { b2b: "b2b", contact: "contact" }, prefix: true
  enum :status, { pending: "pending", in_progress: "in_progress", resolved: "resolved" }, prefix: true

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, presence: true
  validates :inquiry_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(s) { where(status: s) }
end
