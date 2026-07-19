require "json"
require "net/http"
require "uri"

class FacebookOauth
  GRAPH_API_BASE = "https://graph.facebook.com/v21.0".freeze
  AUTHORIZE_BASE = "https://www.facebook.com/v21.0/dialog/oauth".freeze
  SCOPES = %w[pages_manage_posts pages_read_engagement public_profile].freeze
  TIMEOUT = 10

  class << self
    def configured?
      app_id.present? && app_secret.present?
    end

    def authorize_url(redirect_uri:, state:)
      uri = URI(AUTHORIZE_BASE)
      uri.query = URI.encode_www_form(
        client_id: app_id,
        redirect_uri: redirect_uri,
        state: state,
        scope: SCOPES.join(","),
        response_type: "code"
      )
      uri.to_s
    end

    def exchange_code(code:, redirect_uri:)
      payload = get_json(
        "oauth/access_token",
        client_id: app_id,
        client_secret: app_secret,
        redirect_uri: redirect_uri,
        code: code
      )
      token = payload&.fetch("access_token", nil)
      Rails.logger.error("Facebook OAuth exchange_code returned no access token") if token.blank?
      token
    rescue StandardError => error
      log_error("exchange_code", error)
      nil
    end

    def list_pages(user_access_token:)
      payload = get_json("me/accounts", access_token: user_access_token)
      Array(payload&.fetch("data", nil)).filter_map do |page|
        next unless page.is_a?(Hash)
        next if page.values_at("id", "name", "access_token").any?(&:blank?)

        page.slice("id", "name", "access_token").symbolize_keys
      end
    rescue StandardError => error
      log_error("list_pages", error)
      []
    end

    private

    def app_id
      ENV["FACEBOOK_APP_ID"]
    end

    def app_secret
      ENV["FACEBOOK_APP_SECRET"]
    end

    def get_json(path, params)
      uri = URI("#{GRAPH_API_BASE}/#{path}")
      uri.query = URI.encode_www_form(params)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      response = http.request(Net::HTTP::Get.new(uri))

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("Facebook OAuth #{path} failed (HTTP #{response.code})")
        return nil
      end

      payload = JSON.parse(response.body)
      if payload["error"]
        Rails.logger.error("Facebook OAuth #{path} returned a Graph API error")
        return nil
      end

      payload
    rescue StandardError => error
      log_error(path, error)
      nil
    end

    def log_error(operation, error)
      Rails.logger.error("Facebook OAuth #{operation} failed: #{error.class}: #{error.message}")
    end
  end
end
