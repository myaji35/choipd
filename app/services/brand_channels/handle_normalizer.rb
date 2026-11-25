require "uri"

module BrandChannels
  module HandleNormalizer
    HOSTS = {
      "naver_blog" => %w[blog.naver.com m.blog.naver.com],
      "facebook_page" => %w[facebook.com www.facebook.com m.facebook.com],
      "instagram" => %w[instagram.com www.instagram.com]
    }.freeze

    URL_FORMATS = {
      "naver_blog" => "https://blog.naver.com/%s",
      "facebook_page" => "https://www.facebook.com/%s",
      "instagram" => "https://www.instagram.com/%s/"
    }.freeze

    RESERVED_PATHS = %w[profile.php pages p people].freeze

    def self.call(platform:, handle:, profile_url:)
      handle = handle.to_s.strip
      profile_url = profile_url.to_s.strip
      hosts = HOSTS[platform]
      return { handle: handle, profile_url: profile_url } unless hosts

      handle = clean_handle(handle_from_url(handle, hosts) || handle)
      handle = clean_handle(handle_from_url(profile_url, hosts).to_s) if handle.empty?
      profile_url = canonical_url(platform, handle) if profile_url.empty? && !handle.empty?

      { handle: handle, profile_url: profile_url }
    end

    def self.canonical_url(platform, handle)
      format = URL_FORMATS[platform]
      format % handle if format && handle && !handle.empty?
    end

    def self.handle_from_url(value, hosts)
      url = if value.match?(%r{\Ahttps?://}i)
        value
      elsif hosts.include?(value.split(/[\/?#]/, 2).first&.downcase)
        "https://#{value}"
      end
      return unless url

      uri = URI.parse(url)
      return unless hosts.include?(uri.host&.downcase) && uri.userinfo.nil?

      segment = uri.path.split("/", 3)[1].to_s
      RESERVED_PATHS.include?(segment) ? "" : segment
    rescue URI::Error
      nil
    end
    private_class_method :handle_from_url

    def self.clean_handle(handle)
      handle.sub(/\A@+/, "").sub(%r{/+\z}, "")
    end
    private_class_method :clean_handle
  end
end
