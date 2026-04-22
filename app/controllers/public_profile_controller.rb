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

  private

  def track_visit(member)
    AnalyticsEvent.track(
      event_name: "page_view",
      event_category: "profile",
      page_path: "/#{member.slug}",
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
