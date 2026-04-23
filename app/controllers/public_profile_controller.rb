class PublicProfileController < ApplicationController
  layout "impd"

  def show
    @member = Member.find_by(slug: params[:slug])
    if @member
      @awards = []  # talent 도메인에서 확장 예정
      @services = @member.member_services.active.sorted
      @portfolio = @member.member_portfolio_items.sorted
      @reviews = @member.member_reviews.public_visible.recent.limit(4)
      @posts = @member.member_posts.published.recent.limit(3)
      @moments = @member.member_photos.ordered.limit(12)
      # 달란트 — .md/.txt 문서 자동 추출 결과를 공개 페이지에 반영.
      @skills = @member.member_skills
                       .includes(:skill)
                       .joins(:skill)
                       .where.not(skills: { canonical_name: nil })
                       .order(weight: :desc, created_at: :desc)
                       .limit(12)
      @doc_count = @member.member_documents.count
      # 파트너 스냅샷: 6시간 캐시. 백그라운드 새로고침.
      if @member.partner_active? && !@member.stats_fresh?
        TowninSnapshotFetcher.fetch!(@member) rescue nil
      end
      track_visit(@member)
      render :member_show
    else
      @distributor = Distributor.find_by(slug: params[:slug])
      if @distributor
        render :distributor_show
      else
        raise ActionController::RoutingError.new("Not Found")
      end
    end
  end

  # 요약 카드 뷰 — 짧은 URL /s/:hash 기본 타겟.
  # 한 화면(뷰포트 fit)에 이름·직함·명함·QR·연락 3버튼 + "전체 프로필 보기 →".
  def card
    @member = Member.find_by(slug: params[:slug])
    raise ActionController::RoutingError.new("Not Found") if @member.nil? || @member.status != "approved"

    @short_link = ShortLink.resolve_or_create(target_path: "/#{@member.slug}/card", member: @member)
    @skills_top = @member.member_skills
                         .includes(:skill)
                         .joins(:skill)
                         .where.not(skills: { canonical_name: nil })
                         .order(weight: :desc)
                         .limit(4)
    track_visit(@member, category: "card_summary")
    render :card_summary
  end

  private

  def track_visit(member, category: "profile")
    AnalyticsEvent.track(
      event_name: "page_view",
      event_category: category,
      page_path: "/#{member.slug}#{category == "card_summary" ? "/card" : ""}",
      page_title: member.name,
      user_id: session[:member_id]&.to_s,
      user_type: session[:member_id] == member.id ? "pd" : "anonymous",
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      device_type: request.user_agent.to_s.downcase.match?(/mobile|android|iphone/) ? "mobile" : "desktop"
    )
  rescue StandardError => e
    Rails.logger.error "[track_visit] #{e.message}"
  end
end
