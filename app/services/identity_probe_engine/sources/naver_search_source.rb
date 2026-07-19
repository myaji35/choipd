# frozen_string_literal: true

module IdentityProbeEngine
  module Sources
    # Naver 검색 API — 한국어 블로그/카페에서 이름+이메일 힌트 검색.
    # 키 없으면 no-op.
    class NaverSearchSource < BaseSource
      def collect(email:, name:, hints:)
        cid = ENV["NAVER_CLIENT_ID"].to_s.strip
        sec = ENV["NAVER_CLIENT_SECRET"].to_s.strip
        return [] if cid.empty? || sec.empty?

        query = build_query(email: email, name: name)
        return [] if query.empty?

        url = "https://openapi.naver.com/v1/search/blog.json?query=#{URI.encode_www_form_component(query)}&display=5"
        data = http_get_json(url, headers: {
          "X-Naver-Client-Id"     => cid,
          "X-Naver-Client-Secret" => sec,
        })
        return [] unless data.is_a?(Hash)

        Array(data["items"]).map do |item|
          {
            source: :naver,
            kind: "blog_post",
            title: strip_tags(item["title"]),
            snippet: strip_tags(item["description"]),
            link: item["link"],
            blogger: item["bloggername"],
            raw_preview: "#{strip_tags(item['title'])} — #{strip_tags(item['description'])}".to_s[0, 500],
          }.compact
        end
      end

      private

      def build_query(email:, name:)
        parts = []
        parts << name if name && !name.empty?
        parts << email.split("@").first if email && !email.empty?
        parts.reject { |p| p.to_s.strip.empty? }.join(" ")
      end

      def strip_tags(s)
        s.to_s.gsub(/<\/?[^>]+>/, "")
      end
    end
  end
end
