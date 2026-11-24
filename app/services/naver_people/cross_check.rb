module NaverPeople
  class CrossCheck
    def initialize(account, sources: TargetSources.new(account))
      @sources = sources
    end

    def sites
      registered = Array(@sources.values_for("naver")["sites"]).map { |url| normalize(url) }
      rows = { "imPD" => Array(@sources.values_for("impd")["sites"]), "LinkedIn" => [ @sources.linkedin_url ].compact }
      rows.flat_map do |source, urls|
        urls.map { |url| { source: source, url: url, registered: registered.include?(normalize(url)) } }
      end
    end

    def linkedin_mismatches
      profile = @sources.linkedin_profile
      return unless profile

      Linkedin::NaverComparison.new(profile, @sources.naver_presenter).mismatches
    end

    private

    def normalize(url)
      address, suffix = url.strip.downcase.split(/(?=[?#])/, 2)
      address.to_s.sub(/\Ahttps?:\/\//, "").sub(/\Awww\./, "").sub(%r{/+\z}, "") + suffix.to_s
    end
  end
end
