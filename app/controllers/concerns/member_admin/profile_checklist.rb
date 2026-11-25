module MemberAdmin::ProfileChecklist
  extend ActiveSupport::Concern

  private

  def build_profile_checklist(from_checklist:)
    [
      [ "profile-photo", "사진 올리기", "얼굴을 보여주면 고객이 더 친근하게 느껴요.", @member.profile_image.present?, { step: 2 } ],
      [ "bio", "자기소개 쓰기", "어떤 일을 하는지 고객에게 알려주세요.", @member.bio.to_s.length >= 50, { step: 2 } ],
      [ "profession-region", "직업·지역 정하기", "고객이 나에게 맞는 전문가인지 알 수 있어요.", @member.profession.present? && @member.region.present?, { step: 2 } ],
      [ "media", "작업 사진 올리기", "작업 사례로 경험을 보여주세요.", @member.member_portfolio_items.exists? || @member.member_photos.exists?, { step: 1, tab: "media" } ],
      [ "services", "서비스 등록하기", "고객이 제공하는 서비스를 쉽게 확인할 수 있어요.", @member.member_services.exists?, nil ],
      [ "docs", "경력 문서 올리기", "경험과 강점을 페이지에 담을 수 있어요.", @member.member_documents.exists?, { step: 1, tab: "docs" } ]
    ].map do |task, action, why, done, editor_options|
      options = { slug: @member.slug }
      options.merge!(from: "checklist", task: task) if from_checklist
      path = if editor_options
        slug_admin_editor_path(**options, **editor_options, anchor: task)
      else
        slug_admin_services_path(**options, anchor: "new-service")
      end
      { key: task, label: MemberAdmin::ChecklistHelper::CHECKLIST_LABELS.fetch(task), action: action, why: why, path: path, done: done }
    end
  end
end
