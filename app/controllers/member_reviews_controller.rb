class MemberReviewsController < ApplicationController
  layout "impd"

  before_action :set_member

  def new
    @review = @member.member_reviews.new
  end

  def create
    if params[:website].present?
      redirect_to member_review_new_path(slug: @member.slug),
                  notice: success_message,
                  status: :see_other
      return
    end

    @review = @member.member_reviews.new(review_params)
    @review.source = "public_form"
    @review.status = "new"

    if @review.save
      redirect_to member_review_new_path(slug: @member.slug),
                  notice: success_message,
                  status: :see_other
    else
      flash.now[:alert] = "입력 내용을 확인해주세요."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_member
    @member = Member.active.find_by!(slug: params[:slug])
  end

  def review_params
    params.require(:member_review).permit(:rating, :content, :reviewer_name, :reviewer_email)
  end

  def success_message
    "후기가 등록되었습니다. #{@member.name}님의 승인 후 공개됩니다."
  end
end
