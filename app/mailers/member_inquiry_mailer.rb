class MemberInquiryMailer < ApplicationMailer
  def notify(inquiry)
    @inquiry = inquiry
    @member = inquiry.member
    return if @member.email.blank? || @member.email.downcase.start_with?("withdrawn@")

    mail(to: @member.email, subject: "[imPD] 새 문의 도착")
  end
end
