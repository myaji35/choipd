module Api
  module V1
    class HealthController < BaseController
      skip_before_action :ensure_admin_user!

      def index
        render_success({
          status: "ok",
          timestamp: Time.current.iso8601,
          version: ENV.fetch("APP_VERSION", "phase-1"),
          db: ActiveRecord::Base.connection.active? ? "connected" : "down"
        })
      end
    end
  end
end
