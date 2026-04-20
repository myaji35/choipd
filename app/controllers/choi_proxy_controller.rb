# Reverse-proxies /choi* requests to the legacy Next.js (impd) container.
# Reason: /choi was a client-shared URL built in Next.js. Phase 1 Rails migration
# didn't include this page yet; this proxy keeps it live until Phase 4 conversion.
require "net/http"
require "uri"

class ChoiProxyController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  UPSTREAM_HOST = ENV.fetch("CHOI_UPSTREAM", "http://impd:3000")
  HOP_BY_HOP = %w[connection keep-alive proxy-authenticate proxy-authorization
                  te trailers transfer-encoding upgrade host content-length].freeze

  def proxy
    upstream = URI.join(UPSTREAM_HOST, request.path)
    upstream.query = request.query_string if request.query_string.present?

    Net::HTTP.start(upstream.host, upstream.port, open_timeout: 5, read_timeout: 15) do |http|
      method_class = Net::HTTP.const_get(request.method.capitalize, false)
      proxied = method_class.new(upstream.request_uri)

      request.headers.each do |name, value|
        next unless name.start_with?("HTTP_") || %w[CONTENT_TYPE CONTENT_LENGTH].include?(name)
        header = name.sub(/^HTTP_/, "").split("_").map { |w| w.capitalize }.join("-")
        next if HOP_BY_HOP.include?(header.downcase)
        proxied[header] = value
      end

      proxied.body = request.body.read if %w[POST PUT PATCH].include?(request.method)

      upstream_response = http.request(proxied)

      upstream_response.each_header do |k, v|
        next if HOP_BY_HOP.include?(k.downcase)
        response.set_header(k, v)
      end

      content_type = upstream_response["content-type"] || "application/octet-stream"
      render body: upstream_response.body.to_s,
             status: upstream_response.code.to_i,
             content_type: content_type
    end
  rescue StandardError => e
    Rails.logger.error("[choi-proxy] #{e.class}: #{e.message}")
    render plain: "/choi 임시 페이지 오류 — 잠시 후 다시 시도해 주세요.", status: :bad_gateway
  end
end
