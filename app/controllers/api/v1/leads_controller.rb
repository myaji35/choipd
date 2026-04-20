module Api
  module V1
    class LeadsController < BaseController
      skip_before_action :ensure_admin_user!, only: [ :create ]

      def create
        lead = Lead.find_or_initialize_by(email: lead_params[:email], tenant_id: tenant_id)
        lead.subscribed_at ||= Time.current
        if lead.save
          render_success({ id: lead.id, email: lead.email }, status: :created)
        else
          render_error("Validation failed", status: :unprocessable_entity, errors: lead.errors.full_messages)
        end
      end

      private

      def lead_params
        params.require(:lead).permit(:email)
      end
    end
  end
end
