class Pd::LeadsController < Pd::BaseController
  def index
    @total_leads = Lead.count
    @pagy, @leads = pagy(Lead.order(subscribed_at: :desc), items: 30)
  end
end
