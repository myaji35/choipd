module NaverPeople
  class TargetSources
    PUBLIC_PROFILE_HOST = ENV.fetch("IMPD_PUBLIC_HOST", "impd.townin.net")

    NAVER_FIELDS = {
      "jobs" => [ "peopleJob", %w[nameTx] ],
      "offices" => [ "peopleOffice", %w[name position] ],
      "schools" => [ "peopleSchool", %w[name major degree] ],
      "prizes" => [ "peoplePrize", %w[name date] ],
      "licenses" => [ "peopleLicense", %w[name date] ]
    }.freeze

    def initialize(account)
      @account = account
    end

    def values_for(source)
      case source
      when "naver" then naver
      when "linkedin" then linkedin
      when "impd" then impd
      else {}
      end
    end

    def naver_presenter
      @naver_presenter ||= Presenter.new(@account.latest_snapshot&.data)
    end

    def linkedin_profile
      return unless linkedin_snapshot

      data = linkedin_snapshot.data
      pages = data["pages"] if data.is_a?(Hash)
      @linkedin_profile ||= Linkedin::ProfileParser.new(pages.is_a?(Hash) ? pages : {}).to_h
    end

    def linkedin_url
      url = (linkedin_snapshot&.profile_account || linkedin_accounts.order(:id).first)&.profile_url&.strip
      url if NaverPeopleTarget.http_url?(url)
    end

    private

    def naver
      presenter = naver_presenter
      values = NAVER_FIELDS.transform_values do |key, fields|
        presenter.entries(key).map { |entry| line(*entry.values_at(*fields)) }.compact_blank
      end
      values["ename"] = presenter.scalar_values["ename"]
      values["careers"] = presenter.entries("peopleCareer").map do |entry|
        finish = entry["current"] == "Y" ? "현재" : naver_date(entry["endDate"])
        period = [ naver_date(entry["startDate"]), finish ].compact_blank.join("~")
        line(period, entry["comment"])
      end.compact_blank
      values["sites"] = (presenter.people.values_at(*Presenter::SITES.keys) +
        presenter.entries("peopleSite").pluck("url")).grep(String).map(&:strip).compact_blank.uniq
      values.compact_blank
    end

    def linkedin
      profile = linkedin_profile || {}
      experiences = Array(profile[:experiences])
      {
        "offices" => experiences.select { |entry| entry[:current] }.map { |entry| line(*entry.values_at(:company, :title)) }.compact_blank,
        "careers" => experiences.map { |entry| line(linkedin_period(entry[:period]), entry.values_at(:company, :title).compact_blank.join(" ")) }.compact_blank,
        "schools" => Array(profile[:education]).map { |entry| line(*entry.values_at(:school, :major)) }.compact_blank,
        "licenses" => Array(profile[:certifications]).map { |entry| line(entry[:name], entry[:issued].to_s[/\A\d{4}/] || entry[:issued]) }.compact_blank,
        "sites" => [ linkedin_url ].compact
      }.compact_blank
    end

    def linkedin_accounts
      scope = ProfileAccount.active.for_platform("linkedin").where(tenant_id: @account.tenant_id)
      return scope.where(member_id: @account.member_id) if @account.member_id

      @linkedin_accounts ||= begin
        ids = scope.limit(2).ids
        ids.one? ? scope.where(id: ids.first) : scope.none
      end
    end

    def linkedin_snapshot
      return @linkedin_snapshot if defined?(@linkedin_snapshot)

      @linkedin_snapshot = ProfileSnapshot.where(profile_account: linkedin_accounts).recent.order(id: :desc).first
    end

    def impd
      member = @account.member
      unless member
        members = Member.for_tenant(@account.tenant_id)
        matches = members.where(name: @account.display_name).limit(2).to_a
        member = matches.one? ? matches.first : member_by_english_name(members)
      end
      return {} unless member

      social = member.social
      urls = social.is_a?(Hash) ? social.values : []
      urls += BrandChannel.where(tenant_id: member.tenant_id, brand: Brand.where(tenant_id: member.tenant_id, member_id: member.id)).pluck(:profile_url)
      if SnsAccount.column_names.include?("profile_url")
        urls += member.sns_accounts.where(tenant_id: member.tenant_id).pluck(:profile_url)
      end
      urls << public_profile_url(slug: member.slug)
      sites = urls.grep(String).map(&:strip).select { |url| NaverPeopleTarget.http_url?(url) }.uniq
      jobs = member.profession.present? ? [ member.profession_label ] : []
      { "jobs" => jobs, "sites" => sites }.compact_blank
    end

    def member_by_english_name(members)
      name = normalized_name(naver_presenter.scalar_values["ename"])
      return if name.empty?

      matches = members.find_each.lazy.select { |member| normalized_name(member.name) == name }.take(2).force
      matches.first if matches.one?
    end

    def normalized_name(name)
      name.to_s.gsub(/[[:space:]]+/, "").downcase
    end

    def public_profile_url(slug:)
      Rails.application.routes.url_helpers.public_profile_url(slug: slug, host: PUBLIC_PROFILE_HOST, protocol: "https", port: nil)
    end

    def line(*parts)
      parts.select { |value| value.is_a?(String) || value.is_a?(Numeric) }.map { |value| value.to_s.squish }.compact_blank.join(" | ")
    end

    def naver_date(value)
      value.to_s.sub(/\A(\d{4})(\d{2})\z/, '\1.\2')
    end

    def linkedin_period(value)
      return unless value.is_a?(String)
      return value unless value.match?(/\A\d{4}년(?: \d{1,2}월)? - (?:현재|\d{4}년(?: \d{1,2}월)?)\z/)

      value.gsub(/년(?: (\d{1,2})월)?/) { Regexp.last_match(1) ? ".#{Regexp.last_match(1).rjust(2, '0')}" : "" }.sub(" - ", "~")
    end
  end
end
