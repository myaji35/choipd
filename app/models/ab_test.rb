class AbTest < ApplicationRecord
  has_many :ab_test_participants, dependent: :destroy

  STATUSES = %w[draft running paused completed archived].freeze

  validates :name, :target_metric, :variants, :traffic_allocation, :created_by, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :recent, -> { order(created_at: :desc) }
  scope :running, -> { where(status: "running") }

  def variants_list
    JSON.parse(variants || "[]") rescue []
  end

  def allocation_hash
    JSON.parse(traffic_allocation || "{}") rescue {}
  end

  def results_hash
    JSON.parse(results || "{}") rescue {}
  end

  def conversion_rate(variant)
    parts = ab_test_participants.where(variant: variant)
    return 0 if parts.empty?
    (parts.where(converted: true).count.to_f / parts.count * 100).round(2)
  end

  # 간단 변형 분배 (가중치 기반)
  def assign_variant(session_id)
    existing = ab_test_participants.find_by(session_id: session_id)
    return existing.variant if existing
    variant = pick_weighted_variant
    ab_test_participants.create!(
      tenant_id: tenant_id, session_id: session_id, variant: variant
    )
    increment!(:total_participants)
    variant
  end

  private

  def pick_weighted_variant
    alloc = allocation_hash
    return variants_list.first if alloc.empty?
    rand_val = rand(100)
    cumulative = 0
    alloc.each do |variant, pct|
      cumulative += pct.to_f
      return variant if rand_val < cumulative
    end
    variants_list.first
  end
end
