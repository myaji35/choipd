class MemberAdmin::FaqsController < MemberAdmin::BaseController
  before_action :set_faq, only: [ :update, :destroy ]

  def index
    @faqs = @member.member_faqs.sorted
  end

  def create
    faq = @member.member_faqs.new(faq_params)

    if faq.save
      redirect_to slug_admin_faqs_path(slug: @member.slug), notice: "FAQ를 등록했습니다."
    else
      @faqs = @member.member_faqs.sorted
      flash.now[:alert] = faq.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @faq.update(faq_params)
      redirect_to slug_admin_faqs_path(slug: @member.slug), notice: "FAQ를 수정했습니다."
    else
      @faqs = @member.member_faqs.sorted
      flash.now[:alert] = @faq.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @faq.destroy!
    redirect_to slug_admin_faqs_path(slug: @member.slug), notice: "FAQ를 삭제했습니다."
  end

  private

  def set_faq
    @faq = @member.member_faqs.find(params[:id])
  end

  def faq_params
    params.require(:member_faq).permit(:question, :answer, :sort_order, :is_published)
  end
end
