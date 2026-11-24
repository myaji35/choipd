module Linkedin
  class NaverComparison
    def initialize(linkedin_profile, naver_presenter)
      @profile = linkedin_profile
      @naver = naver_presenter
    end

    def comparable?
      @profile.values_at(:experiences, :education, :certifications).any? { |entries| !entries.nil? }
    end

    def mismatches
      career_mismatches +
        compare_names("학력", @profile[:education]&.pluck(:school), naver_names("peopleSchool")) +
        compare_names("자격증", @profile[:certifications]&.pluck(:name), naver_names("peopleLicense"))
    end

    private

    def career_mismatches
      return [] if @profile[:experiences].nil?

      current = @profile[:experiences].select { |entry| entry[:current] }
      offices = @naver.entries("peopleOffice").select { |office| office["current"] == "Y" }
      jobs = @naver.entries("peopleJob").pluck("nameTx").compact_blank
      differences = compare_names("현재 소속", current.pluck(:company), offices.pluck("name"))
      current.each do |entry|
        matches = offices.select { |office| same_name?(entry[:company], office["name"]) }
        titled = matches.select { |office| office["position"].present? }
        next if titled.empty? || titled.any? { |office| same_name?(entry[:title], office["position"]) }

        naver_careers = titled.map { |office| career(office["name"], office["position"]) }
        differences << mismatch("현재 직함", career(entry[:company], entry[:title]), naver_careers.join(", "), "직함 다름")
      end
      differences + jobs.filter_map do |job|
        next if current.any? { |entry| same_name?(entry[:title], job) }

        mismatch("직업", nil, job, "LinkedIn에는 없음")
      end
    end

    def naver_names(key)
      @naver.entries(key).pluck("name")
    end

    def compare_names(topic, linkedin, naver)
      return [] if linkedin.nil?

      linkedin = linkedin.compact_blank.uniq
      naver = naver.compact_blank.uniq
      missing = linkedin.reject { |name| naver.any? { |other| same_name?(name, other) } }
      extra = naver.reject { |name| linkedin.any? { |other| same_name?(name, other) } }
      missing.map { |name| mismatch(topic, name, nil, "네이버에는 없음") } +
        extra.map { |name| mismatch(topic, nil, name, "LinkedIn에는 없음") }
    end

    def same_name?(first, second)
      first = normalize(first)
      second = normalize(second)
      first.present? && second.present? && (first.include?(second) || second.include?(first))
    end

    def normalize(value)
      value.to_s.downcase.gsub(/\s+/, "").gsub(/\(주\)|주식회사|,?inc\./, "")
    end

    def career(company, title)
      [ company, title ].compact_blank.join(" · ")
    end

    def mismatch(topic, linkedin, naver, note)
      { topic: topic, linkedin: linkedin, naver: naver, note: note }
    end
  end
end
