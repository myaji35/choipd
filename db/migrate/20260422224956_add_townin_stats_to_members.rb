class AddTowninStatsToMembers < ActiveRecord::Migration[8.1]
  def change
    # Townin 파트너의 "지금 일하고 있다"는 증거용 스냅샷.
    # 포맷: { monthly_revenue, monthly_revenue_delta_pct, customer_count, customer_delta,
    #        issues_resolved_week, active_days_streak, rating, review_count,
    #        last_activity_at, recent_activities:[{type,title,at}], tenure_months }
    add_column :members, :townin_stats_json, :text
    add_column :members, :stats_synced_at, :datetime
    # revenue_exact | revenue_range | revenue_delta | revenue_hidden
    add_column :members, :stats_display_mode, :string, default: "revenue_range"
  end
end
