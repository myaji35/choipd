class MemberInquiriesController < ApplicationController
  def create
    member = Member.active.find_by!(slug: params[:slug])

    if params[:website].present?
      redirect_back fallback_location: public_profile_path(slug: member.slug),
                    notice: "보냈어요. 보통 24시간 안에 답장이 와요.",
                    status: :see_other
      return
    end

    unless params.dig(:member_inquiry, :consent) == "1"
      redirect_to public_profile_path(slug: member.slug, anchor: "contact"), alert: "개인정보 전달에 동의해 주세요.", status: :see_other
      return
    end

    inquiry = member.member_inquiries.create(inquiry_params)

    if inquiry.persisted?
      MemberInquiryMailer.notify(inquiry).deliver_later
      redirect_back fallback_location: public_profile_path(slug: member.slug),
                    notice: "보냈어요. 보통 24시간 안에 답장이 와요.",
                    status: :see_other
    else
      redirect_back fallback_location: public_profile_path(slug: member.slug),
                    alert: inquiry.errors.full_messages.join(" · "),
                    status: :see_other
    end
  end

  private

  def inquiry_params
    params.require(:member_inquiry).permit(:sender_name, :sender_email, :message)
  end
end
