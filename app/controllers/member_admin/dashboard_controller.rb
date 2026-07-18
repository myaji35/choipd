class MemberAdmin::DashboardController < MemberAdmin::BaseController
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
    @link_clicks = ShortLink.where(member_id: @member.id).sum(:click_count)

    # 14일 방문 추이 (owner 제외)
    @bar_data = (0..13).map { |i|
      d = today - i.days
      count = visit_scope.where(created_at: d.beginning_of_day..d.end_of_day).count
      [d, count]
    }.reverse

    @recent_inquiries = @member.member_inquiries.recent.limit(4)

    @checklist = build_checklist
    @completion_pct = (@checklist.count { |c| c[:done] } * 100 / @checklist.size)
  end

  private

  def build_checklist
    [
      { label: "프로필 사진 업로드", done: @member.profile_image.present? },
      { label: "자기소개 작성 (50자 이상)", done: @member.bio.to_s.length >= 50 },
      { label: "직업/지역 설정", done: @member.profession.present? && @member.region.present? },
      { label: "포트폴리오 1개 이상", done: @member.member_portfolio_items.exists? },
      { label: "서비스 1개 이상 등록", done: @member.member_services.exists? },
      { label: ".md 문서 업로드 (달란트 추출)", done: @member.member_documents.exists? }
    ]
  end
end
