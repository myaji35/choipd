module Api
  module V1
    class AuthController < BaseController
      def me
        render_success(
          id: current_admin_user.id,
          username: current_admin_user.username,
          role: current_admin_user.role,
          email: current_admin_user.email
        )
      end

      def sessions
        render_success(active: warden.authenticated?(:admin_user))
      end
    end
  end
end
