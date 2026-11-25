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

    @checklist = build_checklist
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

  def build_checklist
    [
      [ "profile-photo", "사진 올리기", "얼굴을 보여주면 고객이 더 친근하게 느껴요.", @member.profile_image.present?, { step: 2 } ],
      [ "bio", "자기소개 쓰기", "어떤 일을 하는지 고객에게 알려주세요.", @member.bio.to_s.length >= 50, { step: 2 } ],
      [ "profession-region", "직업·지역 정하기", "고객이 나에게 맞는 전문가인지 알 수 있어요.", @member.profession.present? && @member.region.present?, { step: 2 } ],
      [ "media", "작업 사진 올리기", "작업 사례로 경험을 보여주세요.", @member.member_portfolio_items.exists? || @member.member_photos.exists?, { step: 1, tab: "media" } ],
      [ "services", "서비스 등록하기", "고객이 제공하는 서비스를 쉽게 확인할 수 있어요.", @member.member_services.exists?, nil ],
      [ "docs", "경력 문서 올리기", "경험과 강점을 페이지에 담을 수 있어요.", @member.member_documents.exists?, { step: 1, tab: "docs" } ]
    ].map do |task, action, why, done, editor_options|
      options = { slug: @member.slug, from: "checklist", task: task }
      path = if editor_options
        slug_admin_editor_path(**options, **editor_options, anchor: task)
      else
        slug_admin_services_path(**options, anchor: "new-service")
      end
      { label: MemberAdmin::ChecklistHelper::CHECKLIST_LABELS.fetch(task), action: action, why: why, path: path, done: done }
    end
  end
end
