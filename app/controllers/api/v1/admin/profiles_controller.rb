module Api
  module V1
    module Admin
      class ProfilesController < BaseController
        def show
          render_success(
            id: current_admin_user.id,
            username: current_admin_user.username,
            email: current_admin_user.email,
            role: current_admin_user.role
          )
        end

        def update
          if current_admin_user.update(profile_params)
            render_success(
              id: current_admin_user.id,
              username: current_admin_user.username,
              email: current_admin_user.email
            )
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: current_admin_user.errors.full_messages)
          end
        end

        private

        def profile_params
          params.require(:profile).permit(:username, :email)
        end
      end
    end
  end
end
