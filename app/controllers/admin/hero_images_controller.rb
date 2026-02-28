class Admin::HeroImagesController < Admin::BaseController
  before_action :set_hero_image, only: [ :edit, :update, :destroy ]

  def index
    @hero_images = HeroImage.ordered
  end

  def new
    @hero_image = HeroImage.new
  end

  def create
    @hero_image = HeroImage.new(hero_image_params)
    if @hero_image.save
      redirect_to admin_hero_images_path, notice: "히어로 이미지가 추가되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @hero_image.update(hero_image_params)
      redirect_to admin_hero_images_path, notice: "히어로 이미지가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @hero_image.destroy
    redirect_to admin_hero_images_path, notice: "히어로 이미지가 삭제되었습니다."
  end

  private

  def set_hero_image
    @hero_image = HeroImage.find(params[:id])
  end

  def hero_image_params
    params.require(:hero_image).permit(:alt_text, :is_active, :display_order, :image)
  end
end
