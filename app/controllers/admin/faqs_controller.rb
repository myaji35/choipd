class Admin::FaqsController < Admin::BaseController
  before_action :set_faq, only: [ :show, :edit, :update, :destroy ]

  def index
    @faqs = FaqKnowledgeBase.for_tenant.sorted
    @faqs = @faqs.by_category(params[:category])
  end

  def show; end
  def new; @faq = FaqKnowledgeBase.new(category: "general"); end

  def create
    keywords_arr = (params[:keywords_text] || "").split(",").map(&:strip).reject(&:blank?)
    @faq = FaqKnowledgeBase.new(
      tenant_id: 1,
      category: params[:category] || "general",
      question: params[:question],
      answer: params[:answer],
      keywords: keywords_arr.to_json,
      priority: params[:priority].to_i,
      is_active: true,
      created_by: current_admin_user.email
    )
    if @faq.save
      redirect_to admin_faq_path(@faq), notice: "FAQ 추가됨"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @faq.update!(params.permit(:category, :question, :answer, :is_active, :priority))
    redirect_to admin_faq_path(@faq)
  end

  def destroy
    @faq.destroy
    redirect_to admin_faqs_path
  end

  private

  def set_faq
    @faq = FaqKnowledgeBase.for_tenant.find(params[:id])
  end
end
