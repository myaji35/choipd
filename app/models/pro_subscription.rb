class ProSubscription < ApplicationRecord
  TIERS = %w[free pro enterprise].freeze
  STATUSES = %w[trial active past_due cancelled].freeze

  validates :owner_id, presence: true, uniqueness: true
  validates :tier, inclusion: { in: TIERS }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: %w[trial active]) }
  scope :paid, -> { where(status: "active") }
  scope :for_owner, ->(oid) { where(owner_id: oid) }

  def trial?
    status == "trial" && trial_ends_at && trial_ends_at > Time.current
  end

  def trial_days_left
    return 0 unless trial?
    ((trial_ends_at - Time.current) / 1.day).ceil
  end

  def active_or_trial?
    %w[trial active].include?(status)
  end

  def self.start_trial!(owner_id:, tier: "pro", days: 14)
    create_or_find_by!(owner_id: owner_id) do |s|
      s.tenant_id = 1
      s.tier = tier
      s.price_krw = 14900
      s.status = "trial"
      s.trial_ends_at = Time.current + days.days
    end
  end

  def activate!(payment_method: "stub")
    update!(
      status: "active",
      payment_method: payment_method,
      current_period_start: Time.current,
      current_period_end: Time.current + 30.days
    )
  end

  def cancel!
    update!(status: "cancelled", cancelled_at: Time.current)
  end
end
