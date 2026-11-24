module Linkedin
  class ProfileParser
    PERIOD = /\A\d{4}년( \d{1,2}월)? - (현재|\d{4}년( \d{1,2}월)?)/
    LOCATION = /\A(대한민국|[^ ]+(특별시|광역시|특별자치시|특별자치도|도|시|군|구))( |\z)|대면근무|원격|하이브리드/
    ABOUT_END = /… 더보기|대표 보유기술|^(?:활동|경력|학력|보유기술|자격증\/수료증|추천|관심분야|스페셜|언어|봉사활동|프로젝트|출판물|수상 경력)$/
    SKILL_TABS = [ "전체", "업계 지식", "도구 및 테크놀로지", "산업 지식", "대인 관계 기술", "기타 기술" ].freeze

    def initialize(pages)
      @pages = pages || {}
    end

    def to_h
      experiences = parse_experiences
      education = parse_education
      skills = parse_skills(experiences, education)
      experiences&.each do |entry|
        next if skills.nil?

        entry[:description] = entry[:description].split("\n").reject do |line|
          line.split(", ").all? { |skill| skills.include?(skill) }
        end.join("\n")
      end
      { basics: parse_basics, experiences: experiences, education: education,
        skills: skills, certifications: parse_certifications }
    end

    private

    def lines(key)
      page = @pages[key]
      return unless page.is_a?(Hash) && !page.key?("error") && page["text"].is_a?(String)

      page["text"].lines.map(&:strip).reject(&:empty?)
    end

    def parse_basics
      body = lines("profile")
      return if body.nil?
      return [] if body.empty?

      contact = body.index("연락처")
      about = body.each_cons(2).find_index([ "모두 표시", "소개" ])&.next || body.index("소개")
      {
        name: body.first,
        headline: body.drop(1).reject { |line| line.match?(/\A\(.*\)\z/) }.first,
        location: (body[contact - 2] if contact && contact >= 2 && body[contact - 1] == "·"),
        about: about ? body.drop(about + 1).join("\n").split(ABOUT_END, 2).first.to_s.strip : ""
      }
    end

    def parse_experiences
      period_entries("experience", "경력") do |heading, period, details|
        title, company_line = heading
        company, employment_type = company_line.to_s.split(" · ", 2)
        locations, description = [], []
        details.each_with_index do |line, offset|
          next if line == "현재" || line.match?(/AI로 강화|보유기술/)

          if offset < 2 && line.length <= 40 && line.match?(LOCATION)
            locations << line
          else
            description << line
          end
        end
        { title: title, company: company, employment_type: employment_type, period: period,
          current: period.include?("현재"), location: locations.join(" · ").presence, description: description.join("\n") }
      end
    end

    def parse_education
      period_entries("education", "학력") do |heading, period, details|
        school, major = heading
        school, major = major, nil if school == "학력"
        skills_line = details.find { |line| line.start_with?("보유기술:") }
        { school: school, major: major, period: period, skills_text: skills_line&.delete_prefix("보유기술:")&.strip }
      end
    end

    def period_entries(key, heading)
      body = lines(key)
      return if body.nil?

      periods = body.each_index.select { |index| index.positive? && body[index].match?(PERIOD) }
      starts = periods.map.with_index do |index, offset|
        first_available = offset.zero? ? 0 : periods[offset - 1] + 1
        start = [ index - 2, first_available ].max
        start += 1 if body[start] == heading && start < index
        start
      end
      periods.map.with_index do |index, offset|
        yield body[starts[offset]...index], body[index].split(" · ", 2).first, body[(index + 1)...(starts[offset + 1] || body.size)]
      end
    end

    def parse_skills(experiences, education)
      body = lines("skills")
      return if body.nil?
      return [] unless body.include?("보유기술")

      context = Array(experiences).map { |entry| "#{entry[:company]} #{entry[:title]}" }
      context += Array(education).pluck(:school)
      body.drop(body.index("보유기술") + 1).reject do |line|
        SKILL_TABS.include?(line) || context.include?(line) || line.match?(/외 회사 \d+곳의 경력|(?:경력|학력) \d+\z/) || line == "현재 활동 없음"
      end.uniq
    end

    def parse_certifications
      body = lines("certifications")
      return if body.nil?
      return [] if body.include?("현재 활동 없음")

      body.each_cons(3).filter_map do |name, issuer, line|
        next unless (issued = line[/\A발행일\s*[:：]\s*(.+)/, 1])

        { name: name, issuer: issuer, issued: issued }
      end
    end
  end
end
