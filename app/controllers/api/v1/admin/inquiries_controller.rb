module Api
  module V1
    module Admin
      class InquiriesController < BaseController
        before_action :set_inquiry, only: [ :show, :update ]

        def index
          inquiries = Inquiry.where(tenant_id: tenant_id).order(created_at: :desc)
          inquiries = inquiries.where(status: params[:status]) if params[:status].present?
          inquiries = inquiries.where(inquiry_type: params[:type]) if params[:type].present?
          render_success(inquiries.as_json)
        end

        def show
          render_success(@inquiry.as_json)
        end

        def update
          if @inquiry.update(inquiry_params)
            render_success(@inquiry.as_json)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: @inquiry.errors.full_messages)
          end
        end

        private

        def set_inquiry
          @inquiry = Inquiry.where(tenant_id: tenant_id).find(params[:id])
        end

        def inquiry_params
          params.require(:inquiry).permit(:status, :name, :email, :phone, :message)
        end
      end
    end
  end
end
