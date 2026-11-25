class MemberAdmin::InquiriesController < MemberAdmin::BaseController
  def index
    inquiries = @member.member_inquiries.recent.to_a
    @new_inquiries, @read_inquiries = inquiries.partition { |inquiry| inquiry.is_read.to_i.zero? }
    @unread_count = @new_inquiries.size
  end

  def toggle_read
    inquiry = @member.member_inquiries.find(params[:id])
    marked_read = inquiry.is_read.to_i.zero?
    inquiry.update!(is_read: marked_read ? 1 : 0)

    flash[:saved_item] = "inquiry-#{inquiry.id}"
    notice = if marked_read
      "확인한 문의로 옮겼어요. 아래 '확인한 문의'에서 다시 볼 수 있어요."
    else
      "새 문의로 되돌렸어요."
    end

    redirect_to slug_admin_inquiries_path(slug: @member.slug), status: :see_other, notice: notice
  end
end
