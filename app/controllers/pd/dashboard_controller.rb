class Pd::DashboardController < Pd::BaseController
  def index
    @upcoming_posts = SnsScheduledPost.upcoming.limit(5)
    @active_projects = KanbanProject.recent.limit(3)
    @total_leads = Lead.count
    @recent_inquiries = Inquiry.recent.limit(5)
    @hero_images = HeroImage.active
  end
end
