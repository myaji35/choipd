class Admin::AiGenerationsController < Admin::BaseController
  before_action :set_gen, only: [ :show, :approve, :destroy ]

  def index
    @generations = AiGeneratedContent.for_tenant.recent
    @generations = @generations.where(content_type: params[:type]) if params[:type].present?
    @generations = @generations.where(status: params[:status]) if params[:status].present?
  end

  def show; end

  def new; end

  def create
    gen = AiGeneratedContent.generate(
      content_type: params[:content_type] || "sns_post",
      prompt: params[:prompt],
      user_id: current_admin_user.email
    )
    redirect_to admin_ai_generation_path(gen), notice: "생성 완료 (stub)"
  end

  def approve
    @gen.approve!
    redirect_to admin_ai_generation_path(@gen), notice: "승인됨"
  end

  def destroy
    @gen.destroy
    redirect_to admin_ai_generations_path
  end

  private

  def set_gen
    @gen = AiGeneratedContent.for_tenant.find(params[:id])
  end
end
