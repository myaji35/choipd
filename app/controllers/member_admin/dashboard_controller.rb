class MemberAdmin::DashboardController < MemberAdmin::BaseController
  include MemberAdmin::ProfileChecklist

  def show
    today = Date.current
    # CRIT-3 fix: owner/admin 트래픽 제외 — user_type='anonymous'만 카운트
    visit_scope = AnalyticsEvent.for_tenant
                                .where(event_name: "page_view", page_path: "/#{@member.slug}")
                                .where(user_type: "anonymous")
    @today_visits = visit_scope.where(created_at: today.beginning_of_day..today.end_of_day).count
    @week_visits = visit_scope.where(created_at: 7.days.ago.beginning_of_day..Time.current).count
    @month_visits = visit_scope.where(created_at: 30.days.ago.beginning_of_day..Time.current).count
    @inquiries_count = @member.member_inquiries.count
    @unread_inquiries = @member.member_inquiries.unread.count
    @services_count = @member.member_services.count
    @faqs_count = @member.member_faqs.count
    @visible_posts_count = @member.member_posts.published.count
    @posts_count = @member.member_posts.count
    @pending_reviews_count = @member.member_reviews.where(status: "new").count
    @bookings_count = @member.member_bookings.count
    @link_clicks = ShortLink.where(member_id: @member.id).sum(:click_count)
    sns_accounts = @member.sns_accounts.includes(:sns_follower_snapshots)
    follower_counts = sns_accounts.filter_map(&:follower_count)
    # 입력된 스냅샷이 하나도 없으면 합계를 0으로 내지 않는다 — 미집계를 수치로 위장하지 않기 위해 nil.
    @total_followers = follower_counts.empty? ? nil : follower_counts.sum
    @followers_missing_count = sns_accounts.size - follower_counts.size

    # 14일 방문 추이 (owner 제외)
    @bar_data = (0..13).map { |i|
      d = today - i.days
      count = visit_scope.where(created_at: d.beginning_of_day..d.end_of_day).count
      [ d, count ]
    }.reverse

    @recent_inquiries = @member.member_inquiries.recent.limit(4)

    @profile_accounts = @member.profile_accounts.active.includes(:profile_snapshots, :naver_people_target, :naver_people_submissions).order(:platform, :id).to_a

    @checklist = build_profile_checklist(from_checklist: true)
    @completion_pct = (@checklist.count { |c| c[:done] } * 100 / @checklist.size)
  end

  private

  helper_method :linkedin_completeness_score

  def linkedin_completeness_score(snapshot)
    data = snapshot&.data
    return if data.blank?

    data = JSON.parse(data) unless data.is_a?(Hash)
    return unless data.is_a?(Hash)

    profile = if data["pages"].is_a?(Hash)
      Linkedin::ProfileParser.new(data["pages"]).to_h
    else
      data.deep_symbolize_keys
    end
    Linkedin::ProfilePresenter.new(profile).completeness_score
  rescue StandardError
    nil
  end
end
