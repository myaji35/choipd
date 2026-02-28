class Distributor < ApplicationRecord
  has_many :distributor_activity_logs, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :invoices, dependent: :destroy

  enum :status, { pending: "pending", approved: "approved", rejected: "rejected", suspended: "suspended" }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :business_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_plan, ->(plan) { where(subscription_plan: plan) }

  def log_activity(activity_type, description, metadata = {})
    distributor_activity_logs.create!(
      activity_type: activity_type,
      description: description,
      metadata: metadata.to_json
    )
  end
end
