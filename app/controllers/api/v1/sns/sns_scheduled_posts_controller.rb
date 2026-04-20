module Api
  module V1
    module Sns
      class SnsScheduledPostsController < BaseController
        before_action :set_post, only: [ :show, :update, :destroy ]

        def index
          posts = SnsScheduledPost.where(tenant_id: tenant_id).order(scheduled_at: :asc)
          posts = posts.where(status: params[:status]) if params[:status].present?
          posts = posts.where(platform: params[:platform]) if params[:platform].present?
          render_success(posts.as_json)
        end

        def show
          render_success(@post.as_json)
        end

        def create
          post = SnsScheduledPost.new(post_params.merge(tenant_id: tenant_id, status: "scheduled"))
          if post.save
            render_success(post.as_json, status: :created)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: post.errors.full_messages)
          end
        end

        def update
          if @post.update(post_params)
            render_success(@post.as_json)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: @post.errors.full_messages)
          end
        end

        def destroy
          @post.destroy
          render_success({ id: @post.id })
        end

        private

        def set_post
          @post = SnsScheduledPost.where(tenant_id: tenant_id).find(params[:id])
        end

        def post_params
          params.require(:sns_scheduled_post).permit(:content_type, :content_id, :platform, :message, :scheduled_at, :status)
        end
      end
    end
  end
end
