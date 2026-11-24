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

  def impd_status_label(status)
    IMPD_STATUS_LABELS.fetch(status.to_s, status)
  end
end
