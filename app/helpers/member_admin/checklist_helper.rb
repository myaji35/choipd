module MemberAdmin::ChecklistHelper
  CHECKLIST_LABELS = {
    "profile-photo" => "프로필 사진 올리기",
    "bio" => "자기소개 50자 넘게 쓰기",
    "profession-region" => "직업과 지역 적기",
    "media" => "작업 사진·사례 올리기",
    "services" => "서비스 1개 넣기",
    "docs" => "경력 적기"
  }.freeze

  def checklist_task_label
    CHECKLIST_LABELS[params[:task]]
  end
end
