class Admin::DistributorsController < Admin::BaseController
  before_action :set_distributor, only: [ :show, :edit, :update, :destroy, :approve, :reject ]

  def index
    @distributors = Distributor.all
    @distributors = @distributors.by_status(params[:status]) if params[:status].present?
    @distributors = @distributors.by_plan(params[:plan]) if params[:plan].present?
    @distributors = @distributors.where("name LIKE ? OR email LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
    @distributors = @distributors.recent

    @pagy, @distributors = pagy(@distributors, items: 20)
  end

  def show
    @activity_logs = @distributor.distributor_activity_logs.recent.limit(20)
  end

  def new
    @distributor = Distributor.new
  end

  def create
    @distributor = Distributor.new(distributor_params)
    if @distributor.save
      redirect_to admin_distributor_path(@distributor), notice: "유통사가 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @distributor.update(distributor_params)
      redirect_to admin_distributor_path(@distributor), notice: "유통사 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @distributor.destroy
    redirect_to admin_distributors_path, notice: "유통사가 삭제되었습니다."
  end

  def approve
    @distributor.update!(status: "approved")
    @distributor.log_activity("status_change", "상태 변경: 승인")
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("distributor-#{@distributor.id}-status", partial: "admin/distributors/status_badge", locals: { distributor: @distributor }) }
      format.html { redirect_to admin_distributors_path, notice: "#{@distributor.name} 승인 완료" }
    end
  end

  def reject
    @distributor.update!(status: "rejected")
    @distributor.log_activity("status_change", "상태 변경: 거부")
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("distributor-#{@distributor.id}-status", partial: "admin/distributors/status_badge", locals: { distributor: @distributor }) }
      format.html { redirect_to admin_distributors_path, notice: "#{@distributor.name} 거부 완료" }
    end
  end

  private

  def set_distributor
    @distributor = Distributor.find(params[:id])
  end

  def distributor_params
    params.require(:distributor).permit(:name, :email, :business_type, :region, :status, :subscription_plan)
  end
end
