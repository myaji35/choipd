class Admin::DashboardController < Admin::BaseController
  def index
    @total_distributors = Distributor.count
    @pending_distributors = Distributor.pending.count
    @approved_distributors = Distributor.approved.count
    @total_revenue = Distributor.sum(:total_revenue)
    @recent_distributors = Distributor.recent.limit(5)
    @recent_inquiries = Inquiry.recent.limit(5)
  end
end
