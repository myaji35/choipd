module BrandOps
  class PublicGate
    MEMBERS_THRESHOLD = 50
    ACTIVE_MIN = 5
    COMMUNICATION_MIN = 10

    def self.status(now: Time.current)
      rows = WeeklyStats.platform(weeks: 4, now: now)
      members_total = rows.last.to_h[:members_total].to_i
      members_threshold = Integer(ENV.fetch("BRAND_OPS_MEMBERS_THRESHOLD", MEMBERS_THRESHOLD.to_s))
      active = rows.last.to_h[:members_active].to_i
      communication = rows.last(4).sum { |row| %i[inquiries reviews posts sns_posts].sum { |key| row[key].to_i } }
      active_required = Integer(ENV.fetch("BRAND_OPS_ACTIVE_MIN", ACTIVE_MIN.to_s))
      communication_required = Integer(ENV.fetch("BRAND_OPS_COMMUNICATION_MIN", COMMUNICATION_MIN.to_s))
      reason = if members_total < members_threshold
        "early"
      elsif active >= active_required && communication >= communication_required
        "criteria_met"
      else
        "criteria_not_met"
      end
      { open: reason != "criteria_not_met", reason: reason, members_total: members_total, members_threshold: members_threshold, active: active, active_required: active_required, communication_4w: communication, communication_required: communication_required }
    end
  end
end
