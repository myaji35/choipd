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
  scope :for_tenant, ->(tenant_id = 1) { where(tenant_id: tenant_id) }

  def approve!(actor: nil)
    update!(status: "approved", approved_at: Time.current)
    log_activity("approve", "분양 승인", actor: actor&.id)
  end

  def reject!(reason: nil, actor: nil)
    update!(status: "rejected")
    log_activity("reject", "분양 거절: #{reason}", actor: actor&.id, reason: reason)
  end

  def suspend!(reason: nil, actor: nil)
    update!(status: "suspended")
    log_activity("suspend", "분양 정지: #{reason}", actor: actor&.id, reason: reason)
  end

  def activate!(actor: nil)
    update!(status: "approved")
    log_activity("activate", "분양 재활성화", actor: actor&.id)
  end

  def log_activity(activity_type, description, metadata = {})
    distributor_activity_logs.create!(
      activity_type: activity_type,
      description: description,
      metadata: metadata.to_json
    )
  end
end
