class MemberInquiriesController < ApplicationController
  def create
    member = Member.publicly_visible.find_by!(slug: params[:slug])

    if params[:website].present?
      flash[:inquiry_sent] = true
      redirect_to public_profile_path(slug: member.slug, anchor: "contact"), status: :see_other
      return
    end

    unless params.dig(:member_inquiry, :consent) == "1"
      redirect_to public_profile_path(slug: member.slug, anchor: "contact"), alert: "개인정보 전달에 동의해 주세요.", status: :see_other
      return
    end

    inquiry = member.member_inquiries.create(inquiry_params)

    if inquiry.persisted?
      MemberInquiryMailer.notify(inquiry).deliver_later
      flash[:inquiry_sent] = true
      redirect_to public_profile_path(slug: member.slug, anchor: "contact"), status: :see_other
    else
      redirect_to public_profile_path(slug: member.slug, anchor: "contact"),
                  alert: inquiry.errors.full_messages.join(" · "),
                  status: :see_other
    end
  end

  private

  def inquiry_params
    params.require(:member_inquiry).permit(:sender_name, :sender_email, :message)
  end
end
