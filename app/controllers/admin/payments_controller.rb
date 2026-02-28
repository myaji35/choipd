class Admin::PaymentsController < Admin::BaseController
  def index
    @pagy, @payments = pagy(Payment.includes(:distributor).recent, items: 20)
  end

  def show
    @payment = Payment.includes(:distributor, :invoice).find(params[:id])
  end
end
