class Chopd::InquiriesController < Chopd::BaseController
  def new
    @inquiry = Inquiry.new
  end

  def create
    @inquiry = Inquiry.new(inquiry_params)

    respond_to do |format|
      if @inquiry.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "inquiry-form",
            partial: "chopd/inquiries/success"
          )
        end
        format.html { redirect_to education_path, notice: "문의가 접수되었습니다." }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "inquiry-form",
            partial: "chopd/inquiries/form",
            locals: { inquiry: @inquiry }
          )
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def inquiry_params
    params.require(:inquiry).permit(:name, :email, :phone, :message, :inquiry_type)
  end
end
