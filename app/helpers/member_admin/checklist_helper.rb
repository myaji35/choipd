module MemberAdmin::ChecklistHelper
  CHECKLIST_LABELS = {
    "profile-photo" => "프로필 사진 올리기",
    "bio" => "자기소개 작성 (50자 이상)",
    "profession-region" => "직업/지역 설정",
    "media" => "작업 사진·사례 1개 이상",
    "services" => "서비스 1개 이상 등록",
    "docs" => "이력서·경력 문서 올리기"
  }.freeze

  def checklist_task_label
    CHECKLIST_LABELS[params[:task]]
  end
end
