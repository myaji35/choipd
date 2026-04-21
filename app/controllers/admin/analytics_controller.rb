class Admin::AnalyticsController < Admin::BaseController
  def index
    @period_days = (params[:days] || 30).to_i
    @from = @period_days.days.ago
    @to = Time.current

    @events_count = AnalyticsEvent.for_tenant.in_period(@from, @to).count
    @unique_users = AnalyticsEvent.for_tenant.in_period(@from, @to).distinct.count(:user_id)
    @top_events = AnalyticsEvent.for_tenant.in_period(@from, @to)
                                .group(:event_name).order(Arel.sql("count_id DESC"))
                                .count(:id).first(10)
    @recent_events = AnalyticsEvent.for_tenant.recent.limit(20)

    # 일별 차트 데이터
    @daily_counts = AnalyticsEvent.for_tenant.in_period(@from, @to)
                                  .group("DATE(created_at)").count

    # 카테고리별
    @category_counts = AnalyticsEvent.for_tenant.in_period(@from, @to)
                                     .group(:event_category).count

    # 디바이스
    @device_counts = AnalyticsEvent.for_tenant.in_period(@from, @to)
                                   .where.not(device_type: nil)
                                   .group(:device_type).count

    @ab_tests_count = AbTest.for_tenant.count
    @cohorts_count = Cohort.for_tenant.count
    @funnels_count = Funnel.for_tenant.count
    @rfm_segments_count = RfmSegment.for_tenant.count
  end

  def events
    @events = AnalyticsEvent.for_tenant.recent
    @events = @events.by_event(params[:event_name])
    @events = @events.by_category(params[:category])
    @events = @events.where(user_id: params[:user_id]) if params[:user_id].present?
    @pagy, @events = pagy(@events, items: 50) if respond_to?(:pagy)
  end
end
