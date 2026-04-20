class Admin::MembersController < Admin::BaseController
  before_action :set_member, only: [ :show, :edit, :update, :destroy, :approve, :reject, :suspend, :activate ]

  def index
    @members = Member.for_tenant.recent
                     .by_status(params[:status])
                     .by_impd(params[:impd])
                     .by_profession(params[:profession])
                     .search(params[:q])
    @pagy, @members = pagy(@members, items: 20) if respond_to?(:pagy)
  end

  def show
    @portfolio_count = @member.member_portfolio_items.count
    @services_count  = @member.member_services.count
    @posts_count     = @member.member_posts.count
    @reviews         = @member.member_reviews.recent.limit(10)
    @inquiries       = @member.member_inquiries.recent.limit(10)
    @documents       = @member.member_documents.order(uploaded_at: :desc)
    @skills          = @member.member_skills.includes(:skill).order(weight: :desc).limit(20)
    @gap_report      = @member.member_gap_reports.order(generated_at: :desc).first
  end

  def new
    @member = Member.new(tenant_id: 1, status: "pending_approval")
  end

  def create
    @member = Member.new(member_params.merge(tenant_id: 1))
    if @member.save
      redirect_to admin_member_path(@member), notice: "회원이 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @member.update(member_params)
      redirect_to admin_member_path(@member), notice: "회원 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @member.destroy
    redirect_to admin_members_path, notice: "회원이 삭제되었습니다."
  end

  def approve
    @member.update!(status: "approved")
    redirect_to admin_member_path(@member), notice: "#{@member.name} 승인 완료"
  end

  def reject
    @member.update!(status: "rejected", rejection_reason: params[:reason])
    redirect_to admin_member_path(@member), notice: "#{@member.name} 거부 완료"
  end

  def suspend
    @member.update!(status: "suspended")
    redirect_to admin_member_path(@member), notice: "#{@member.name} 정지 완료"
  end

  def activate
    @member.update!(status: "approved")
    redirect_to admin_member_path(@member), notice: "#{@member.name} 재활성화 완료"
  end

  private

  def set_member
    @member = Member.for_tenant.find_by(slug: params[:id]) || Member.for_tenant.find(params[:id])
  end

  def member_params
    params.require(:member).permit(
      :name, :email, :phone, :slug, :bio, :profile_image, :cover_image,
      :business_type, :profession, :region, :status, :subscription_plan,
      :is_featured, :featured_order, :impd_status, :rejection_reason
    )
  end
end
