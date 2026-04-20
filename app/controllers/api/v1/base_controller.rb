module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::Cookies
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :ensure_admin_user!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable
      rescue_from ActionController::ParameterMissing, with: :bad_request

      private

      def render_success(data = nil, status: :ok, **extra)
        payload = data.nil? ? extra : data
        render json: { success: true, data: payload }, status: status
      end

      def render_error(message, status: :bad_request, errors: nil)
        payload = { success: false, error: message }
        payload[:errors] = errors if errors
        render json: payload, status: status
      end

      def ensure_admin_user!
        unless current_admin_user
          render_error("Unauthorized", status: :unauthorized)
        end
      end

      def current_admin_user
        @current_admin_user ||= warden.user(:admin_user)
      end

      def warden
        request.env["warden"]
      end

      def not_found(exception)
        render_error(exception.message, status: :not_found)
      end

      def unprocessable(exception)
        render_error("Validation failed", status: :unprocessable_entity, errors: exception.record.errors.full_messages)
      end

      def bad_request(exception)
        render_error(exception.message, status: :bad_request)
      end

      def tenant_id
        params[:tenant_id] || 1
      end
    end
  end
end
