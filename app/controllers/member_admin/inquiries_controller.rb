class MemberAdmin::InquiriesController < MemberAdmin::BaseController
  def index
    @inquiries = @member.member_inquiries.recent
    @unread_count = @member.member_inquiries.unread.count
  end

  def toggle_read
    inquiry = @member.member_inquiries.find(params[:id])
    inquiry.update!(is_read: inquiry.is_read.to_i.zero? ? 1 : 0)

    redirect_to slug_admin_inquiries_path(slug: @member.slug), status: :see_other
  end
end
