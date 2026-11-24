module Admin::MembersHelper
  MEMBER_STATUS_LABELS = {
    "pending_approval" => "승인 대기",
    "approved" => "승인",
    "rejected" => "거부",
    "suspended" => "정지"
  }.freeze

  IMPD_STATUS_LABELS = {
    "none" => "미신청",
    "in_progress" => "진행 중",
    "completed" => "인증 완료",
    "rejected" => "반려"
  }.freeze

  def member_status_label(status)
    MEMBER_STATUS_LABELS.fetch(status.to_s, status)
  end

  def member_capabilities(member)
    public_profile = member.approved? && !member.withdrawn?
    {
      login_and_edit: member.can_sign_in?,
      public_profile: public_profile,
      townin_section: public_profile && member.partner_active?
    }
  end

  def impd_status_label(status)
    IMPD_STATUS_LABELS.fetch(status.to_s, status)
  end
end
