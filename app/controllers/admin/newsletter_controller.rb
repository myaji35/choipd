class Admin::NewsletterController < Admin::BaseController
  def index
    @pagy, @leads = pagy(Lead.order(subscribed_at: :desc), items: 30)
  end
end
