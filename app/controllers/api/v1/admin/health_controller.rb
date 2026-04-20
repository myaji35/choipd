module Api
  module V1
    module Admin
      class HealthController < BaseController
        def index
          render_success(
            status: "ok",
            db: ActiveRecord::Base.connection.active? ? "connected" : "down",
            counts: {
              distributors: Distributor.where(tenant_id: tenant_id).count,
              posts: Post.where(tenant_id: tenant_id).count,
              inquiries: Inquiry.where(tenant_id: tenant_id).count,
              leads: Lead.where(tenant_id: tenant_id).count,
              hero_images: HeroImage.where(tenant_id: tenant_id).count
            }
          )
        end
      end
    end
  end
end
