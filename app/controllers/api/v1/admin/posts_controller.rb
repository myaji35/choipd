module Api
  module V1
    module Admin
      class PostsController < BaseController
        before_action :set_post, only: [ :show, :update, :destroy ]

        def index
          posts = Post.where(tenant_id: tenant_id).order(created_at: :desc)
          posts = posts.where(category: params[:category]) if params[:category].present?
          posts = posts.where(published: params[:published] == "true") if params.key?(:published)
          render_success(posts.as_json)
        end

        def show
          render_success(@post.as_json)
        end

        def create
          post = Post.new(post_params.merge(tenant_id: tenant_id))
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
          @post = Post.where(tenant_id: tenant_id).find(params[:id])
        end

        def post_params
          params.require(:post).permit(:title, :content, :category, :published)
        end
      end
    end
  end
end
