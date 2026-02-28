class Admin::InvoicesController < Admin::BaseController
  def index
    @pagy, @invoices = pagy(Invoice.includes(:distributor).recent, items: 20)
  end

  def show
    @invoice = Invoice.includes(:distributor, :payment).find(params[:id])
  end
end
