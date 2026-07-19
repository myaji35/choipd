# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "timeout"

module IdentityProbeEngine
  module Sources
    # 공통 인터페이스. 각 소스는 #fetch(email:, name:) → {signals: [...], source: :xxx}를 반환한다.
    # 실패 시 반드시 {signals: [], source: self.source_key}를 반환하고 raise하지 않는다.
    class BaseSource
      TIMEOUT_SEC = 2
      UA = "Mozilla/5.0 (compatible; imPD-IdentityProbe/1.0; +https://impd.kr)"

      def self.source_key
        name.split("::").last.sub(/Source\z/, "").downcase.to_sym
      end

      def fetch(email:, name: nil, hints: {})
        Timeout.timeout(TIMEOUT_SEC) do
          signals = collect(email: email.to_s.strip.downcase, name: name.to_s.strip, hints: hints || {})
          { signals: Array(signals), source: self.class.source_key }
        end
      rescue => e
        Rails.logger.info("[IdentityProbe:#{self.class.source_key}] fetch failed: #{e.class}: #{e.message}")
        { signals: [], source: self.class.source_key }
      end

      # 서브클래스가 구현한다. 반드시 Array<Hash>를 반환.
      def collect(email:, name:, hints:)
        []
      end

      protected

      def http_get_json(url, headers: {})
        res = http_get(url, headers: headers)
        return nil unless res&.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)
      rescue JSON::ParserError
        nil
      end

      def http_get(url, headers: {})
        uri = URI.parse(url)
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = UA
        headers.each { |k, v| req[k] = v }

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: TIMEOUT_SEC, open_timeout: TIMEOUT_SEC) do |http|
          http.request(req)
        end
      rescue => e
        Rails.logger.debug("[IdentityProbe:http_get] #{url} → #{e.class}: #{e.message}")
        nil
      end

      def http_head(url)
        uri = URI.parse(url)
        req = Net::HTTP::Head.new(uri)
        req["User-Agent"] = UA

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: TIMEOUT_SEC, open_timeout: TIMEOUT_SEC) do |http|
          http.request(req)
        end
      rescue => e
        Rails.logger.debug("[IdentityProbe:http_head] #{url} → #{e.class}: #{e.message}")
        nil
      end
    end
  end
end
