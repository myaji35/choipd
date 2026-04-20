module Api
  module V1
    module Admin
      class InvoicesController < BaseController
        before_action :set_invoice, only: [ :show, :resend ]

        def index
          invoices = Invoice.where(tenant_id: tenant_id).order(created_at: :desc)
          render_success(invoices.as_json(include: :distributor))
        end

        def show
          render_success(@invoice.as_json(include: :distributor))
        end

        def resend
          render_success({ id: @invoice.id, resent_at: Time.current.iso8601, status: "queued" })
        end

        private

        def set_invoice
          @invoice = Invoice.where(tenant_id: tenant_id).find(params[:id])
        end
      end
    end
  end
end
