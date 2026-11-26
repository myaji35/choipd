module MemberAdmin::ProfileChecklist
  extend ActiveSupport::Concern

  private

  def build_profile_checklist(from_checklist:)
    [
      [ "services", "서비스 등록하기", "무슨 일을 해 주는지 적어야 고객이 문의할 수 있어요.", @member.member_services.exists?, nil ],
      [ "bio", "자기소개 쓰기", "어떤 분께 무엇을 해 드리는지 두세 줄이면 돼요.", @member.bio.to_s.length >= 50, { step: 2 } ],
      [ "profile-photo", "사진 올리기", "얼굴을 보여주면 고객이 더 친근하게 느껴요.", @member.profile_image.present?, { step: 2 } ],
      [ "profession-region", "직업·지역 정하기", "고객이 나에게 맞는 전문가인지 알 수 있어요.", @member.public_profession_label.present? && @member.region.present?, { step: 2 } ],
      [ "media", "작업 사진 올리기", "작업 사례로 경험을 보여주세요.", @member.member_portfolio_items.exists? || @member.gallery_photos.exists?, { step: 1, tab: "media" } ],
      [ "docs", "경력 적기", "언제부터 어떤 일을 했는지 적으면 고객이 믿고 문의해요.", @member.career_note.to_s.strip.present? || @member.member_documents.exists?, { step: 2, anchor: "career-note" } ]
    ].map do |task, action, why, done, editor_options|
      options = { slug: @member.slug }
      options.merge!(from: "checklist", task: task) if from_checklist
      path = if editor_options
        slug_admin_editor_path(**options, **editor_options.except(:anchor), anchor: editor_options[:anchor] || task)
      else
        slug_admin_services_path(**options, anchor: "new-service")
      end
      { key: task, label: MemberAdmin::ChecklistHelper::CHECKLIST_LABELS.fetch(task), action: action, why: why, path: path, done: done }
    end
  end
end
