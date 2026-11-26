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

    attrs = inquiry_params.to_h.transform_values { |value| value.to_s.strip }
    problem =
      if attrs.values_at("sender_name", "sender_email", "message").any?(&:blank?)
        "이름·연락처·문의 내용을 모두 적어 주세요."
      elsif !attrs["sender_email"].match?(/[^@\s]+@[^@\s]+\.[^@\s]+/) && attrs["sender_email"].scan(/\d/).size < 9
        "답장받을 전화번호나 메일 주소를 다시 확인해 주세요."
      elsif attrs["message"].length < 5
        "문의 내용을 다섯 글자 이상 적어 주세요."
      elsif attrs["message"].length > 2000
        "문의 내용은 2,000자까지 보낼 수 있어요."
      end
    if problem
      redirect_to public_profile_path(slug: member.slug, anchor: "contact"), alert: problem, status: :see_other
      return
    end

    inquiry = member.member_inquiries.create(attrs)

    if inquiry.persisted?
      MemberInquiryMailer.notify(inquiry).deliver_later
      flash[:inquiry_sent] = true
      flash[:inquiry_contact] = attrs["sender_email"]
      redirect_to public_profile_path(slug: member.slug, anchor: "contact"), status: :see_other
    else
      redirect_to public_profile_path(slug: member.slug, anchor: "contact"),
                  alert: "문의를 보내지 못했어요. 잠시 뒤 다시 보내 주세요.",
                  status: :see_other
    end
  end

  private

  def inquiry_params
    params.require(:member_inquiry).permit(:sender_name, :sender_email, :message)
  end
end
