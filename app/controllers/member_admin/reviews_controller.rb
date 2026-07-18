class MemberAdmin::ReviewsController < MemberAdmin::BaseController
  before_action :set_review, only: [ :update, :approve, :reject, :destroy ]

  def index
    @reviews = @member.member_reviews.recent
    @review_groups = {
      "승인 대기" => @reviews.select { |review| review.status == "new" },
      "공개 중" => @reviews.select { |review| review.status.in?(%w[triaged responded]) },
      "보관" => @reviews.select { |review| review.status == "archived" }
    }
    @pending_count = @review_groups.fetch("승인 대기").size
    @review_request_url = member_review_new_url(slug: @member.slug)
  end

  def update
    if @review.update(review_params)
      redirect_to slug_admin_reviews_path(slug: @member.slug), notice: "후기 상태를 변경했습니다.", status: :see_other
    else
      redirect_to slug_admin_reviews_path(slug: @member.slug), alert: "후기 상태를 변경하지 못했습니다.", status: :see_other
    end
  end

  def approve
    @review.update!(status: "triaged")
    redirect_to slug_admin_reviews_path(slug: @member.slug), notice: "후기를 승인해 공개했습니다.", status: :see_other
  end

  def reject
    @review.update!(status: "archived")
    redirect_to slug_admin_reviews_path(slug: @member.slug), notice: "후기를 보관했습니다.", status: :see_other
  end

  def destroy
    @review.destroy!
    redirect_to slug_admin_reviews_path(slug: @member.slug), notice: "후기를 삭제했습니다.", status: :see_other
  end

  private

  def set_review
    @review = @member.member_reviews.find(params[:id])
  end

  def review_params
    params.require(:member_review).permit(:status)
  end
end
