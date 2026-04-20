module Api
  module V1
    module Admin
      class CoursesController < BaseController
        before_action :set_course, only: [ :show, :update, :destroy ]

        def index
          courses = Course.where(tenant_id: tenant_id).order(created_at: :desc)
          courses = courses.published if params[:published] == "true"
          courses = courses.by_type(params[:type]) if params[:type].present?
          render_success(courses.as_json)
        end

        def show
          render_success(@course.as_json)
        end

        def create
          course = Course.new(course_params.merge(tenant_id: tenant_id))
          if course.save
            render_success(course.as_json, status: :created)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: course.errors.full_messages)
          end
        end

        def update
          if @course.update(course_params)
            render_success(@course.as_json)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: @course.errors.full_messages)
          end
        end

        def destroy
          @course.destroy
          render_success({ id: @course.id })
        end

        private

        def set_course
          @course = Course.where(tenant_id: tenant_id).find(params[:id])
        end

        def course_params
          params.require(:course).permit(:title, :description, :course_type, :price, :thumbnail_url, :external_link, :published)
        end
      end
    end
  end
end
