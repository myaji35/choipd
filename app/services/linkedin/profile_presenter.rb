module Linkedin
  class ProfilePresenter
    BASIC_LABELS = { name: "이름", headline: "헤드라인", location: "위치", about: "소개" }.freeze
    SECTIONS = { experiences: "경력", education: "학력", skills: "기술", certifications: "자격증" }.freeze
    ITEM_FIELDS = {
      experiences: %i[title company employment_type period location description],
      education: %i[school major period skills_text],
      certifications: %i[name issuer issued]
    }.freeze

    def initialize(profile)
      @profile = profile
    end

    def sections
      basics = @profile[:basics]
      details = basics.presence
      rows = BASIC_LABELS.except(:about).filter_map do |key, label|
        { label: label, value: details[key] } if details&.dig(key).present?
      end
      [
        { key: :basics, title: "기본정보", rows: (rows unless basics.nil?) },
        { key: :about, title: "소개", text: (details&.dig(:about).to_s unless basics.nil?) }
      ] + SECTIONS.map do |key, title|
        { key: key, title: title, items: @profile[key]&.map { |item| self.class.render_item(key, item) } }
      end
    end

    def self.render_item(key, item)
      return item if key == :skills

      item.values_at(*ITEM_FIELDS.fetch(key)).compact_blank.join(" · ")
    end

    def completeness
      basics = @profile[:basics]&.presence
      experiences = @profile[:experiences]
      current = experiences&.select { |entry| entry[:current] }
      [
        check(:headline, "헤드라인", @profile[:basics], basics&.dig(:headline).present?, "하는 일을 한 줄로 적어 보세요."),
        check(:about, "소개 100자 이상", @profile[:basics], basics&.dig(:about).to_s.length >= 100, "하는 일과 강점을 100자 이상 적어 보세요."),
        check(:location, "위치", @profile[:basics], basics&.dig(:location).present?, "활동하는 지역을 적어 보세요."),
        check(:experiences, "경력", experiences, experiences&.any?, "경력을 한 개 이상 추가해 보세요."),
        check(:current, "현재 재직 경력", experiences, current&.any?, "지금 하고 있는 일을 경력에 추가해 보세요."),
        check(:current_descriptions, "현재 경력 설명", experiences, current&.any? && current.all? { |entry| entry[:description].present? }, "현재 경력마다 맡은 일과 성과를 적어 보세요."),
        check(:education, "학력", @profile[:education], @profile[:education]&.any?, "학교를 한 곳 이상 추가해 보세요."),
        check(:skills, "기술 5개 이상", @profile[:skills], Array(@profile[:skills]).size >= 5, "잘하는 기술을 다섯 개 이상 추가해 보세요."),
        check(:certifications, "자격증", @profile[:certifications], @profile[:certifications]&.any?, "보유한 자격증을 한 개 이상 추가해 보세요.")
      ]
    end

    def completeness_score
      known = completeness.reject { |item| item[:filled].nil? }
      return if known.empty?

      (known.count { |item| item[:filled] } * 100.0 / known.size).round
    end

    private

    def check(key, label, source, filled, hint)
      { key: key, label: label, filled: source.nil? ? nil : filled, hint: source.nil? ? "확인 못 함" : hint }
    end
  end
end
