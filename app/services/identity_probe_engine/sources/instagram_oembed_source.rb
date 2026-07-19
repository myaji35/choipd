# frozen_string_literal: true

module IdentityProbeEngine
  module Sources
    # Instagram 공개 프로필 존재 여부 확인.
    # 이름으로 후보 핸들 3개를 추측 → HEAD 요청으로 200인 것만 수용.
    class InstagramOembedSource < BaseSource
      def collect(email:, name:, hints:)
        handles = candidate_handles(email: email, name: name)
        return [] if handles.empty?

        hits = []
        handles.first(3).each do |handle|
          url = "https://www.instagram.com/#{handle}/"
          res = http_head(url)
          next unless res.is_a?(Net::HTTPSuccess) || (res.is_a?(Net::HTTPRedirection) && res["location"].to_s.include?(handle))
          hits << {
            source: :instagram,
            kind: "profile_candidate",
            handle: handle,
            profile_url: url,
            confidence_hint: "handle_guessed_from_name",
            raw_preview: "https://www.instagram.com/#{handle}/",
          }
        end

        hits
      end

      private

      # 이름·이메일에서 ascii 소문자 기반 후보 핸들을 만든다.
      def candidate_handles(email:, name:)
        candidates = []
        if name && !name.empty?
          ascii = name.to_s.gsub(/\s+/, "").downcase
          # 한글 등 비-ascii는 현재 단계에서는 아이디로 쓸 수 없으므로 skip.
          if ascii.match?(/\A[a-z0-9._-]+\z/)
            candidates << ascii
            candidates << ascii.gsub("-", "_")
            candidates << ascii.gsub(/[._-]/, "")
          end
        end
        if email && !email.empty?
          local = email.split("@").first.to_s.downcase
          candidates << local if local.match?(/\A[a-z0-9._-]+\z/)
          candidates << local.gsub(/[._-]/, "") if local.match?(/\A[a-z0-9._-]+\z/)
        end

        candidates.reject { |c| c.nil? || c.length < 3 || c.length > 30 }.uniq
      end
    end
  end
end
