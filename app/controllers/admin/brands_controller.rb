class Admin::BrandsController < Admin::BaseController
  before_action :set_brand, only: [ :edit, :update, :destroy ]

  def index
    @brands = Brand.recent
    @brands = @brands.where(business_type: params[:business_type]) if params[:business_type].present?
    @brands = @brands.where(published: params[:published] == "true") if params[:published].present?
    @pagy, @brands = pagy(@brands, items: 24) if respond_to?(:pagy)
  end

  def new
    @brand = Brand.new
  end

  def create
    @brand = Brand.new(brand_params)
    if @brand.save
      redirect_to admin_brands_path, notice: "브랜드가 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @brand.update(brand_params)
      redirect_to admin_brands_path, notice: "브랜드가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @brand.destroy
    redirect_to admin_brands_path, notice: "브랜드가 삭제되었습니다."
  end

  private

  def set_brand
    @brand = Brand.find(params[:id])
  end

  def brand_params
    params.require(:brand).permit(:name, :slug, :website_url, :description, :logo_url, :business_type, :region, :published)
  end
end
