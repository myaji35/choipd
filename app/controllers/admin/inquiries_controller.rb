class Admin::InquiriesController < Admin::BaseController
  before_action :set_inquiry, only: [ :show, :update ]

  def index
    @inquiries = Inquiry.all
    @inquiries = @inquiries.by_status(params[:status]) if params[:status].present?
    @inquiries = @inquiries.recent

    @pagy, @inquiries = pagy(@inquiries, items: 20)
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
