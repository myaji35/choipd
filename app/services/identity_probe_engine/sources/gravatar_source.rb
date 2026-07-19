# frozen_string_literal: true

require "digest"

module IdentityProbeEngine
  module Sources
    # Gravatar 프로필 JSON. 404면 빈 신호.
    class GravatarSource < BaseSource
      def collect(email:, name:, hints:)
        return [] if email.blank?
        hash = Digest::MD5.hexdigest(email)
        url  = "https://www.gravatar.com/#{hash}.json?d=404"
        data = http_get_json(url)
        return [] unless data.is_a?(Hash)

        entries = Array(data["entry"])
        signals = []

        entries.each do |entry|
          signals << {
            source: :gravatar,
            kind: "profile",
            display_name: entry["displayName"],
            bio: entry["aboutMe"],
            avatar_url: entry["thumbnailUrl"] || entry.dig("photos", 0, "value"),
            profile_url: entry["profileUrl"],
            location: entry["currentLocation"],
            urls: Array(entry["urls"]).map { |u| u["value"] }.compact,
            raw_preview: entry.slice("displayName", "aboutMe", "currentLocation").to_s[0, 500],
          }.compact
        end

        signals
      end
    end
  end
end
