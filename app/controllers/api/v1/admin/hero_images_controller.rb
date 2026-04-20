module Api
  module V1
    module Admin
      class HeroImagesController < BaseController
        before_action :set_hero_image, only: [ :show, :update, :destroy ]

        def index
          images = HeroImage.where(tenant_id: tenant_id).order(created_at: :desc)
          images = images.where(is_active: true) if params[:active] == "true"
          render_success(images.as_json)
        end

        def show
          render_success(@hero_image.as_json)
        end

        def create
          image = HeroImage.new(hero_image_params.merge(tenant_id: tenant_id, uploaded_at: Time.current))
          if image.save
            render_success(image.as_json, status: :created)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: image.errors.full_messages)
          end
        end

        def update
          if @hero_image.update(hero_image_params)
            render_success(@hero_image.as_json)
          else
            render_error("Validation failed", status: :unprocessable_entity, errors: @hero_image.errors.full_messages)
          end
        end

        def destroy
          @hero_image.destroy
          render_success({ id: @hero_image.id })
        end

        private

        def set_hero_image
          @hero_image = HeroImage.where(tenant_id: tenant_id).find(params[:id])
        end

        def hero_image_params
          params.require(:hero_image).permit(:filename, :url, :alt_text, :file_size, :width, :height, :upload_status, :is_active, :display_order)
        end
      end
    end
  end
end
