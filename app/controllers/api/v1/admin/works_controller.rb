module Api
  module V1
    module Admin
      class WorksController < BaseController
        before_action :set_work, only: [ :show, :update, :destroy ]

        def index
          works = Work.where(tenant_id: tenant_id).order(created_at: :desc)
          works = works.where(category: params[:category]) if params[:category].present?
          render_success(works.as_json)
        end

        def show
          render_success(@work.as_json)
        end

        def create
          work = Work.new(work_params.merge(tenant_id: tenant_id))
          if work.save
            render_success(work.as_json, status: :created)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: work.errors.full_messages)
          end
        end

        def update
          if @work.update(work_params)
            render_success(@work.as_json)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: @work.errors.full_messages)
          end
        end

        def destroy
          @work.destroy
          render_success({ id: @work.id })
        end

        private

        def set_work
          @work = Work.where(tenant_id: tenant_id).find(params[:id])
        end

        def work_params
          params.require(:work).permit(:title, :description, :image_url, :category)
        end
      end
    end
  end
end
