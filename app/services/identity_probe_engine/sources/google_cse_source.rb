# frozen_string_literal: true

module IdentityProbeEngine
  module Sources
    # Google Custom Search Engine. 키 없으면 no-op.
    class GoogleCseSource < BaseSource
      def collect(email:, name:, hints:)
        key = ENV["GOOGLE_CSE_KEY"].to_s.strip
        cx  = ENV["GOOGLE_CSE_ID"].to_s.strip
        return [] if key.empty? || cx.empty?

        q = build_query(email: email, name: name)
        return [] if q.empty?

        url = "https://www.googleapis.com/customsearch/v1?key=#{URI.encode_www_form_component(key)}&cx=#{URI.encode_www_form_component(cx)}&num=5&q=#{URI.encode_www_form_component(q)}"
        data = http_get_json(url)
        return [] unless data.is_a?(Hash)

        Array(data["items"]).map do |item|
          {
            source: :google_cse,
            kind: "search_result",
            title: item["title"],
            snippet: item["snippet"],
            link: item["link"],
            display_link: item["displayLink"],
            raw_preview: "#{item['title']} — #{item['snippet']}".to_s[0, 500],
          }.compact
        end
      end

      private

      def build_query(email:, name:)
        parts = []
        parts << "\"#{name}\"" if name && !name.empty?
        parts << "\"#{email}\"" if email && !email.empty?
        parts.join(" ")
      end
    end
  end
end
