module Api
  module V1
    class InquiriesController < BaseController
      skip_before_action :ensure_admin_user!, only: [ :create ]

      def create
        inquiry = Inquiry.new(inquiry_params.merge(tenant_id: tenant_id, status: "pending"))
        if inquiry.save
          render_success({ id: inquiry.id }, status: :created)
        else
          render_error("Validation failed", status: :unprocessable_entity, errors: inquiry.errors.full_messages)
        end
      end

      private

      def inquiry_params
        params.require(:inquiry).permit(:name, :email, :phone, :message, :inquiry_type)
      end
    end
  end
end
