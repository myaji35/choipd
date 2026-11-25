class MemberAdmin::FaqsController < MemberAdmin::BaseController
  before_action :set_faq, only: [ :update, :destroy ]

  def index
    @faqs = @member.member_faqs.sorted
  end

  def create
    faq = @member.member_faqs.new(faq_params)

    if faq.save
      flash[:saved_item] = "faq-#{faq.id}"
      redirect_to slug_admin_faqs_path(slug: @member.slug), notice: "질문을 저장했어요. 내 페이지에서 볼 수 있어요."
    else
      @faqs = @member.member_faqs.sorted
      flash.now[:alert] = faq.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @faq.update(faq_params)
      flash[:saved_item] = "faq-#{@faq.id}"
      message = if params[:visibility_toggle].present?
        @faq.is_published.to_i == 1 ? "질문을 내 페이지에 보이게 했어요." : "질문을 내 페이지에서 숨겼어요."
      else
        "질문을 고쳤어요."
      end
      redirect_to slug_admin_faqs_path(slug: @member.slug), notice: message
    else
      @faqs = @member.member_faqs.sorted
      flash.now[:alert] = @faq.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @faq.destroy!
    redirect_to slug_admin_faqs_path(slug: @member.slug), notice: "질문을 지웠어요."
  end

  private

  def set_faq
    @faq = @member.member_faqs.find(params[:id])
  end

  def faq_params
    params.require(:member_faq).permit(:question, :answer, :sort_order, :is_published)
  end
end
