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

    @checklist = build_checklist
    @completion_pct = (@checklist.count { |c| c[:done] } * 100 / @checklist.size)
  end

  private

  def build_checklist
    [
      { label: "프로필 사진 업로드", why: "얼굴을 보여주면 고객이 더 친근하게 느껴요.", path: slug_admin_editor_path(slug: @member.slug, step: 1), done: @member.profile_image.present? },
      { label: "자기소개 작성 (50자 이상)", why: "어떤 일을 하는지 고객에게 알려주세요.", path: slug_admin_editor_path(slug: @member.slug, step: 2), done: @member.bio.to_s.length >= 50 },
      { label: "직업/지역 설정", why: "고객이 나에게 맞는 전문가인지 알 수 있어요.", path: slug_admin_editor_path(slug: @member.slug, step: 2), done: @member.profession.present? && @member.region.present? },
      { label: "포트폴리오 1개 이상", why: "작업 사례로 경험을 보여주세요.", path: slug_admin_editor_path(slug: @member.slug, step: 1), done: @member.member_portfolio_items.exists? },
      { label: "서비스 1개 이상 등록", why: "고객이 제공하는 서비스를 쉽게 확인할 수 있어요.", path: slug_admin_services_path(slug: @member.slug), done: @member.member_services.exists? },
      { label: "이력서·경력 문서 올리기", why: "경험과 강점을 페이지에 담을 수 있어요.", path: slug_admin_editor_path(slug: @member.slug, step: 1), done: @member.member_documents.exists? }
    ]
  end
end
