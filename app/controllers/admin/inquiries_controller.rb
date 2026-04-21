class Admin::InquiriesController < Admin::BaseController
  before_action :set_inquiry, only: [ :show, :update ]

  def index
    @inquiries = Inquiry.all
    @inquiries = @inquiries.where(status: params[:status]) if params[:status].present?
    @inquiries = @inquiries.where(inquiry_type: params[:type]) if params[:type].present?
    @inquiries = @inquiries.where("name LIKE ? OR email LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
    @inquiries = @inquiries.order(created_at: :desc)
    @pagy, @inquiries = pagy(@inquiries, items: 20) if respond_to?(:pagy)
  end

  def show; end

  def update
    @inquiry.update!(inquiry_params)
    redirect_to admin_inquiry_path(@inquiry), notice: "상태가 업데이트되었습니다."
  end

  private

  def set_inquiry
    @inquiry = Inquiry.find(params[:id])
  end

  def inquiry_params
    params.require(:inquiry).permit(:status)
  end
end
