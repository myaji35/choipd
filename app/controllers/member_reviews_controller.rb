class MemberReviewsController < ApplicationController
  layout "impd"

  before_action :set_member

  def new
    @review = @member.member_reviews.new
  end

  def create
    if params[:website].present?
      flash[:review_sent] = true
      redirect_to member_review_new_path(slug: @member.slug), status: :see_other
      return
    end

    @review = @member.member_reviews.new(review_params)
    @review.source = "public_form"
    @review.status = "new"

    if @review.save
      flash[:review_sent] = true
      redirect_to member_review_new_path(slug: @member.slug), status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_member
    @member = Member.publicly_visible.find_by!(slug: params[:slug])
  end

  def review_params
    params.require(:member_review).permit(:rating, :content, :reviewer_name, :reviewer_email)
  end
end
