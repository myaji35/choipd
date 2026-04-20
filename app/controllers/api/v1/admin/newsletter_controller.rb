module Api
  module V1
    module Admin
      class NewsletterController < BaseController
        before_action :set_lead, only: [ :destroy ]

        def index
          leads = Lead.where(tenant_id: tenant_id).order(subscribed_at: :desc)
          render_success({
            total: leads.count,
            leads: leads.as_json
          })
        end

        def destroy
          @lead.destroy
          render_success({ id: @lead.id })
        end

        private

        def set_lead
          @lead = Lead.where(tenant_id: tenant_id).find(params[:id])
        end
      end
    end
  end
end
