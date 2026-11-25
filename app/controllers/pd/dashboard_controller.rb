class Pd::DashboardController < Pd::BaseController
  include Pd::MemberRegistrationStatus

  def index
    rows = member_registration_rows(Member.for_tenant.includes(:profile_accounts, brands: :brand_channels))
    @registration_progress_count = rows.count { |row| registration_in_progress?(row) }
    @registration_todo_count = rows.count { |row| registration_todo?(row) }
    @consent_waiting_count = rows.count { |row| row.fetch(:consent_waiting).positive? }
    @connection_todo_count = rows.count { |row| row.fetch(:connection_todo).positive? }
    @upcoming_posts = SnsScheduledPost.upcoming.limit(5)
    @active_projects = KanbanProject.recent.limit(3)
    @total_leads = Lead.count
    @recent_inquiries = Inquiry.recent.limit(5)
    @hero_images = HeroImage.active
  end
end
