module Api
  module V1
    module Admin
      class PaymentsController < BaseController
        before_action :set_payment, only: [ :show, :refund ]

        def index
          payments = Payment.where(tenant_id: tenant_id).order(created_at: :desc)
          payments = payments.where(status: params[:status]) if params[:status].present?
          render_success(payments.as_json(include: :distributor))
        end

        def show
          render_success(@payment.as_json(include: :distributor))
        end

        def refund
          if @payment.update(status: "refunded", refunded_at: Time.current)
            render_success(@payment.as_json)
          else
            render_error("Refund failed", status: :unprocessable_entity, errors: @payment.errors.full_messages)
          end
        end

        private

        def set_payment
          @payment = Payment.where(tenant_id: tenant_id).find(params[:id])
        end
      end
    end
  end
end
