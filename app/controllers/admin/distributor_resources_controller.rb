class Admin::DistributorResourcesController < Admin::BaseController
  before_action :set_resource, only: [ :edit, :update, :destroy ]

  def index
    @resources = DistributorResource.all
    @resources = @resources.by_category(params[:category]) if params[:category].present?
    @resources = @resources.recent

    @pagy, @resources = pagy(@resources, items: 20)
  end

  def new
    @resource = DistributorResource.new
  end

  def create
    @resource = DistributorResource.new(resource_params)
    if @resource.save
      redirect_to admin_resources_path, notice: "자료가 추가되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @resource.update(resource_params)
      redirect_to admin_resources_path, notice: "자료가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @resource.destroy
    redirect_to admin_resources_path, notice: "자료가 삭제되었습니다."
  end

  private

  def set_resource
    @resource = DistributorResource.find(params[:id])
  end

  def resource_params
    params.require(:distributor_resource).permit(:title, :file_url, :file_type, :category, :required_plan, :file)
  end
end
