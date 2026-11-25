module Pd::MembersHelper
  def member_login_status_label(member)
    member.withdrawn? ? "탈퇴" : member_status_label(member.status)
  end
end
