module NaverPeople
  class SearchExposure
    SEARCH_URL = "https://search.naver.com/search.naver"
    BOX_LABELS = %w[출생 신체 소속 소속그룹 소속사 학력 경력 사이트 활동 관련활동 수상 데뷔 작품 취미 특기 종교 가족 병역].freeze

    attr_reader :checked_at

    def initialize(data)
      data = data.is_a?(Hash) ? data : {}
      @search = data["search"]
      @dss = data["dss"].to_s.presence
      @presenter = Presenter.new(data)
      @checked_at = @search["checked_at"] if collected?
    end

    def collected? = @search.is_a?(Hash)

    def results
      raw_results.map do |result|
        main = main_box(result)
        query = result["query"]
        {
          query: query, status: status(result), main_os: main["os"]&.to_s,
          main_name: main["name"], main_job: main["job"], main_aliases: Array(main["aliases"]), error: result["error"],
          search_url: search_url(query)
        }
      end
    end

    def namesakes
      raw_results.flat_map do |result|
        main = main_box(result)
        same_name = people_in(result)
        same_name + [ main.merge("details" => [ main["job"] ]) ]
      end.filter_map do |person|
        os = person["os"].to_s.presence
        next if os.nil? || os == @dss

        name = person["name"]
        { os: os, name: name, details: Array(person["details"]).reject(&:blank?).join(" · "),
          url: search_url(name, pkid: 1, os: os) }
      end.uniq { |person| person[:os] }
    end

    def box_comparison
      result = raw_results.find { |entry| status(entry) == "main" }
      return [] unless result

      main = main_box(result)
      fields = parse_box(main["profile_text"])
      [
        comparison("이름", main["name"], @presenter.scalar_values["name"]),
        entry_comparison("직업", main["job"], "peopleJob", %w[nameTx]),
        entry_comparison("소속", fields["소속"], "peopleOffice", %w[name]),
        entry_comparison("학력", fields["학력"], "peopleSchool", %w[name major degree]),
        entry_comparison("경력", fields["경력"], "peopleCareer")
      ]
    end

    def changes_from(older_data)
      older = self.class.new(older_data).results.index_by { |result| result[:query] }
      results.filter_map do |result|
        query = result[:query]
        before = older.dig(query, :status)
        after = result[:status]
        { query: query, before: before, after: after } if before && before != after
      end
    end

    private

    def raw_results
      return [] unless collected? && @search["results"].is_a?(Array)

      @search["results"].grep(Hash)
    end

    def main_box(result)
      result["main"].is_a?(Hash) ? result["main"] : {}
    end

    def people_in(result)
      result["same_name"].is_a?(Array) ? result["same_name"].grep(Hash) : []
    end

    def status(result)
      return "error" if result["error"].present?
      return "main" if @dss && main_box(result)["os"].to_s == @dss
      return "same_name" if @dss && people_in(result).any? { |person| person["os"].to_s == @dss }

      "absent"
    end

    def search_url(query, **options)
      "#{SEARCH_URL}?#{URI.encode_www_form(where: "nexearch", **options, query: query)}"
    end

    def parse_box(profile_text)
      label = nil
      fields = Hash.new { |hash, key| hash[key] = [] }
      profile_text.to_s.each_line do |line|
        line = line.strip
        break if line.start_with?("본인 또는 대리인이 직접 관리하는 정보입니다.", "본인참여")

        if BOX_LABELS.include?(line)
          label = line
        elsif label && line.present?
          fields[label] << line
        end
      end
      fields.transform_values { |lines| lines.join("\n") }
    end

    def entry_comparison(label, search_value, key, fields = nil)
      entries = @presenter.entries(key)
      rendered = entries.map { |entry| @presenter.render_item(key, entry) }
      values = if fields
        entries.map { |entry| entry.values_at(*fields).compact.join(" ") }
      else
        rendered.map { |value| value.sub(/현재(?= · |\z)/, "") }
      end
      comparison(label, search_value, rendered.join("\n"), values)
    end

    def comparison(label, search_value, profile_value, values = [ profile_value ])
      search = normalize(search_value)
      expected = values.map { |value| normalize(value) }.reject(&:empty?)
      match = if search.present? || expected.any?
        search.present? && expected.any? && expected.all? { |value| search.include?(value) }
      end
      { label: label, search_value: search_value, profile_value: profile_value, match: match }
    end

    def normalize(value) = value.to_s.downcase.gsub(/[^\p{Alnum}]/, "")
  end
end
