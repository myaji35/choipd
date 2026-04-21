require "csv"

class Admin::NewsletterController < Admin::BaseController
  def index
    @leads = Lead.order(subscribed_at: :desc)
    @leads = @leads.where("email LIKE ?", "%#{params[:q]}%") if params[:q].present?

    respond_to do |format|
      format.html do
        @pagy, @leads = pagy(@leads, items: 50) if respond_to?(:pagy)
      end
      format.csv do
        csv = CSV.generate(headers: true) do |c|
          c << ["id", "email", "subscribed_at", "created_at"]
          @leads.find_each { |l| c << [l.id, l.email, l.subscribed_at, l.created_at] }
        end
        send_data csv, filename: "newsletter-#{Date.today}.csv", type: "text/csv"
      end
    end
  end
end
