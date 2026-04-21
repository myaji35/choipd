class Funnel < ApplicationRecord
  validates :name, :steps, :created_by, presence: true

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }

  def steps_list
    JSON.parse(steps || "[]") rescue []
  end

  def conversion_data_hash
    JSON.parse(conversion_data || "{}") rescue {}
  end

  # 단계별 전환율 계산 (analytics_events 기반)
  def calculate!
    step_names = steps_list
    return if step_names.empty?

    counts = step_names.map { |s|
      AnalyticsEvent.for_tenant(tenant_id)
                    .where(event_name: s)
                    .where("created_at > ?", conversion_window.days.ago)
                    .distinct.count(:user_id)
    }

    data = step_names.zip(counts).map.with_index { |(name, c), i|
      prev = i > 0 ? counts[i - 1] : counts[0]
      rate = prev.zero? ? 0 : (c.to_f / counts[0] * 100).round(2)
      step_rate = (i.zero? || prev.zero?) ? 100 : (c.to_f / prev * 100).round(2)
      { step: name, count: c, total_rate: rate, step_rate: step_rate }
    }
    update!(conversion_data: data.to_json, total_users: counts[0])
    data
  end
end
