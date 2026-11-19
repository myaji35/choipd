module NaverPeople
  class Presenter
    SCALARS = { "name" => "이름", "rname" => "본명", "ename" => "영문명", "viewName" => "표시 이름", "birth" => "출생", "sex" => "성별", "regionName" => "활동 지역" }.freeze
    SITES = { "blog" => "블로그", "instagram" => "인스타그램", "twitter" => "트위터", "facebook" => "페이스북", "youtube" => "유튜브", "officialHomepage" => "공식 홈페이지" }.freeze
    ARRAYS = { "peopleJob" => "직업", "peopleOffice" => "소속", "peopleCareer" => "경력", "peopleSchool" => "학력", "peoplePrize" => "수상", "peopleLicense" => "자격증", "peopleWorkList" => "작품·활동", "peopleSite" => "사이트", "peopleNickname" => "취향·기타", "peopleHobby" => "취향·기타", "peopleLanguage" => "취향·기타", "peopleMilitaryService" => "취향·기타", "peopleFamily" => "취향·기타", "peoplePet" => "취향·기타", "peopleLikeBook" => "취향·기타", "peopleLikeMovieBroadcast" => "취향·기타", "peopleLikeMusic" => "취향·기타", "peopleLikeDestination" => "취향·기타" }.freeze

    attr_reader :people, :auth
    def initialize(data)
      data = data.is_a?(Hash) ? data : {}
      @people = data["people"].is_a?(Hash) ? data["people"] : {}
      @auth = data["auth"].is_a?(Hash) ? data["auth"] : {}
    end

    def scalar_values
      birth = %w[birthYear birthMonth birthDay].map { |k| text(people[k]) }
      SCALARS.keys.index_with do |key|
        case key
        when "birth" then birth.all?(&:present?) ? [ birth[0], birth[1].rjust(2, "0"), birth[2].rjust(2, "0") ].join("-") : birth.reject(&:blank?).join("-")
        when "sex" then { "M" => "남", "F" => "여" }.fetch(text(people[key]), text(people[key]))
        else text(people[key])
        end
      end
    end

    def entries(key)
      value = people[key]
      value.is_a?(Array) ? value.select { |item| item.is_a?(Hash) } : []
    end

    def render_item(key, item)
      parts = case key
      when "peopleJob" then [ item["nameTx"], ("#{item['annual']}년 차" if item["annual"].present?), ("현직" if item["current"] == "Y") ]
      when "peopleOffice" then [ item["name"], item["position"], item["department"], ("현직" if item["current"] == "Y") ]
      when "peopleCareer" then [ [ date(item["startDate"]), (item["current"] == "Y" ? "현재" : date(item["endDate"])) ].reject(&:blank?).join(" ~ "), item["comment"] ]
      when "peopleSchool" then [ [ item["name"], item["major"], item["degree"] ].map { |v| text(v) }.reject(&:blank?).join(" "), ("(#{[text(item['enterDate']), text(item['graduateDate'])].join('~')})" if item["enterDate"].present? || item["graduateDate"].present?) ]
      when "peopleWorkList" then [ item["kind"], item["comment"], item["date"] ]
      else %w[name comment title url date kind gubun].map { |k| item[k] }
      end
      result = parts.map { |v| text(v) }.reject(&:blank?).join(" · ")
      result.presence || JSON.generate(item)
    end

    def sections
      result = [ { key: "basic", title: "기본정보", rows: scalar_values.filter_map { |k, v| { label: SCALARS[k], value: v } if v.present? } } ]
      ARRAYS.values.uniq.each do |title|
        keys = ARRAYS.select { |_, v| v == title }.keys
        items = keys.flat_map do |key|
          list = entries(key)
          list = list.sort_by { |item| text(item["startDate"]) }.reverse if key == "peopleCareer"
          list.map { |item| render_item(key, item) }
        end
        items += SITES.filter_map { |key, label| "#{label} · #{text(people[key])}" if text(people[key]).present? } if title == "사이트"
        result << { key: keys.first, title: title, items: items }
      end
      rows = []
      rows << { label: "관계", value: auth["relKind"] == "ME" ? "본인" : "대리" } if text(auth["relKind"]).present?
      rows << { label: "상태", value: auth["status"] == "ACCEPT" ? "승인" : text(auth["status"]) } if text(auth["status"]).present?
      period = %w[delegStartDate delegEndDate].map { |k| text(auth[k]) == "2999-12-31" ? "무기한" : text(auth[k]) }.reject(&:blank?).join(" ~ ")
      rows << { label: "위임 기간", value: period } if period.present?
      result << { key: "auth", title: "권한", rows: rows }
    end

    def completeness
      checks = { "profileImgFull" => "프로필 사진", "ename" => "영문명", "peopleJob" => "직업", "peopleOffice" => "소속", "peopleCareer" => "경력", "peopleSchool" => "학력", "peoplePrize" => "수상", "peopleLicense" => "자격증", "site" => "사이트 정보", "peopleWorkList" => "작품·활동" }
      checks.map do |key, label|
        filled = if key == "site"
          entries("peopleSite").any? || SITES.keys.any? { |k| text(people[k]).present? }
        elsif key.start_with?("people")
          entries(key).any?
        else
          text(people[key]).present?
        end
        { key: key, label: label, filled: filled, hint: key == "site" ? "LinkedIn·블로그 주소를 사이트 정보로 등록하면 검색 박스에 노출됩니다." : "#{label} 정보를 등록해 보세요." }
      end
    end

    def completeness_score = (completeness.count { |check| check[:filled] } * 100.0 / completeness.size).round

    private
      def text(value) = value.is_a?(String) || value.is_a?(Numeric) ? value.to_s.strip : ""
      def date(value)
        value = text(value)
        value.match?(/\A\d{6}\z/) ? "#{value[0, 4]}.#{value[4, 2]}" : value
      end
  end
end
