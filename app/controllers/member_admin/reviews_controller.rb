class MemberAdmin::ReviewsController < MemberAdmin::BaseController
  before_action :set_review, only: [ :update, :approve, :reject, :destroy ]

  def index
    @reviews = @member.member_reviews.recent
    @review_groups = {
      "확인할 후기" => @reviews.select { |review| review.status == "new" },
      "내 페이지에 보이는 후기" => @reviews.select { |review| review.status.in?(%w[triaged responded]) },
      "숨긴 후기" => @reviews.select { |review| review.status == "archived" }
    }
    @pending_count = @review_groups.fetch("확인할 후기").size
    @review_request_url = member_review_new_url(slug: @member.slug)
  end

  def update
    if @review.update(review_params)
      flash[:saved_item] = "review-#{@review.id}"
      redirect_to slug_admin_reviews_path(slug: @member.slug), notice: "후기 상태를 바꿨어요.", status: :see_other
    else
      redirect_to slug_admin_reviews_path(slug: @member.slug), alert: "후기 상태를 바꾸지 못했어요. 다시 시도해 주세요.", status: :see_other
    end
  end

  def approve
    @review.update!(status: "triaged")
    flash[:saved_item] = "review-#{@review.id}"
    redirect_to slug_admin_reviews_path(slug: @member.slug), notice: "후기를 내 페이지에 공개했어요.", status: :see_other
  end

  def reject
    @review.update!(status: "archived")
    flash[:saved_item] = "review-#{@review.id}"
    redirect_to slug_admin_reviews_path(slug: @member.slug), notice: "후기를 숨겼어요. '숨긴 후기'에서 다시 공개할 수 있어요.", status: :see_other
  end

  def destroy
    @review.destroy!
    redirect_to slug_admin_reviews_path(slug: @member.slug), notice: "후기를 지웠어요.", status: :see_other
  end

  private

  def set_review
    @review = @member.member_reviews.find(params[:id])
  end

  def review_params
    params.require(:member_review).permit(:status)
  end
end
