module Api
  module V1
    module Admin
      class DistributorsController < BaseController
        before_action :set_distributor, only: [ :show, :update, :destroy, :approve, :reject, :suspend, :activate, :identity ]

        def index
          distributors = Distributor.for_tenant(tenant_id).recent
          distributors = distributors.where(status: params[:status]) if params[:status].present?
          render_success(distributors.as_json)
        end

        def show
          render_success(@distributor.as_json)
        end

        def create
          distributor = Distributor.new(distributor_params.merge(tenant_id: tenant_id))
          if distributor.save
            distributor.log_activity("create", "신규 분양 등록", actor: current_admin_user.id)
            render_success(distributor.as_json, status: :created)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: distributor.errors.full_messages)
          end
        end

        def update
          if @distributor.update(distributor_params)
            render_success(@distributor.as_json)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: @distributor.errors.full_messages)
          end
        end

        def destroy
          @distributor.destroy
          render_success({ id: @distributor.id })
        end

        def approve
          @distributor.approve!(actor: current_admin_user)
          render_success(@distributor.reload.as_json)
        end

        def reject
          @distributor.reject!(reason: params[:reason], actor: current_admin_user)
          render_success(@distributor.reload.as_json)
        end

        def suspend
          @distributor.suspend!(reason: params[:reason], actor: current_admin_user)
          render_success(@distributor.reload.as_json)
        end

        def activate
          @distributor.activate!(actor: current_admin_user)
          render_success(@distributor.reload.as_json)
        end

        def identity
          render_success(@distributor.as_json(only: [ :id, :name, :slug, :email, :status, :business_type, :region ]))
        end

        def check_id
          slug = params[:slug].to_s.strip
          available = slug.present? && !Distributor.where(slug: slug).exists?
          render_success({ slug: slug, available: available })
        end

        private

        def set_distributor
          @distributor = Distributor.for_tenant(tenant_id).find(params[:id])
        end

        def distributor_params
          params.require(:distributor).permit(:name, :email, :phone, :business_type, :region, :status, :subscription_plan, :slug)
        end
      end
    end
  end
end
