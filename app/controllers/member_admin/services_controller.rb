class MemberAdmin::ServicesController < MemberAdmin::BaseController
  before_action :set_service, only: [ :update, :destroy ]

  def index
    @services = @member.member_services.sorted
  end

  def create
    service = @member.member_services.new(service_params)

    if service.save
      redirect_to slug_admin_services_path(slug: @member.slug), notice: "서비스를 저장했어요. 내 페이지 '서비스' 칸에서 볼 수 있어요."
    else
      @services = @member.member_services.sorted
      flash.now[:alert] = service.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @service.update(service_params)
      redirect_to slug_admin_services_path(slug: @member.slug), notice: "서비스를 고쳤어요."
    else
      @services = @member.member_services.sorted
      flash.now[:alert] = @service.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @service.destroy!
    redirect_to slug_admin_services_path(slug: @member.slug), notice: "서비스를 지웠어요."
  end

  def reorder
    service_ids = Array(params[:service_ids]).map(&:to_i)
    owned_services = @member.member_services.where(id: service_ids).index_by(&:id)

    MemberService.transaction do
      service_ids.each_with_index do |id, index|
        owned_services[id]&.update!(sort_order: index)
      end
    end

    render json: { success: true }
  end

  private

  def set_service
    @service = @member.member_services.find(params[:id])
  end

  def service_params
    params.require(:member_service).permit(
      :title,
      :description,
      :price,
      :price_label,
      :cta_label,
      :cta_url,
      :image_url,
      :is_active,
      :sort_order
    )
  end
end
