class Admin::DashboardController < Admin::BaseController
  def index
    @total_members = Member.count
    @pending_members = Member.by_status("pending_approval").count
    @approved_members = Member.by_status("approved").count
    @suspended_members = Member.by_status("suspended").count
    @recent_pending_members = Member.by_status("pending_approval").recent.limit(5)
    @recent_inquiries = Inquiry.recent.limit(5)
  end
end
