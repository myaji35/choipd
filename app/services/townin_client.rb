# Townin API Client (ISS-321, 2026-04-22)
#
# imPD에서 Townin 백엔드(api.townin.net)로 server-to-server 호출 수행.
# CHOPD_API_KEY(최PD 전용 API 키)를 X-API-Key 헤더로 전송.
#
# 엔드포인트:
#   GET  /api/v1/users/lookup-by-email?email=xxx
#   PATCH /api/v1/users/:id/upgrade-role
#
# 환경변수:
#   TOWNIN_API_URL  — 기본: https://api.townin.net/api/v1
#   TOWNIN_API_KEY  — Townin에서 발급한 CHOPD_API_KEY 값
#
# 모든 메서드는 실패 시 TowninClient::Error 파생 예외를 raise.
# 호출자가 rescue하여 UX 폴백 처리한다.
require "net/http"
require "uri"
require "json"

class TowninClient
  class Error < StandardError; end
  class NotFound < Error; end
  class Unauthorized < Error; end
  class BadRequest < Error; end
  class ServerError < Error; end

  DEFAULT_BASE_URL = "https://api.townin.net/api/v1".freeze
  DEFAULT_TIMEOUT = 10  # seconds

  def self.base_url
    ENV["TOWNIN_API_URL"].presence || DEFAULT_BASE_URL
  end

  def self.api_key
    ENV["TOWNIN_API_KEY"].presence
  end

  def self.enabled?
    api_key.present?
  end

  # ── Public API ──────────────────────────────────────────────

  # 이메일로 Townin 사용자 조회.
  # 반환: { "found" => true, "user" => { "id", "email", "displayName", "role", "partnerId" } }
  #       또는 { "found" => false }
  def self.lookup_by_email(email)
    raise Error, "TOWNIN_API_KEY 미설정" unless enabled?

    uri = URI.parse("#{base_url}/users/lookup-by-email")
    uri.query = URI.encode_www_form(email: email)

    response = request_with_key(Net::HTTP::Get.new(uri), uri)
    parse_body(response)
  end

  # Townin 사용자를 PARTNER(또는 MERCHANT/FP)로 승격 + partners 레코드 자동 생성.
  # 반환: { "success" => true, "userId", "newRole", "upgradedAt", "partnerId" }
  def self.upgrade_role(user_id:, target_role: "partner", verification_id:, completed_at: nil)
    raise Error, "TOWNIN_API_KEY 미설정" unless enabled?

    uri = URI.parse("#{base_url}/users/#{user_id}/upgrade-role")
    req = Net::HTTP::Patch.new(uri)
    req["Content-Type"] = "application/json"
    req.body = {
      targetRole: target_role,
      impdVerificationId: verification_id,
      impdCompletedAt: completed_at || Time.current.iso8601,
    }.to_json

    response = request_with_key(req, uri)
    parse_body(response)
  end

  # ── Internal ────────────────────────────────────────────────

  def self.request_with_key(req, uri)
    req["X-API-Key"] = api_key
    req["Accept"] = "application/json"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.read_timeout = DEFAULT_TIMEOUT
    http.open_timeout = DEFAULT_TIMEOUT

    http.request(req)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "Townin API 타임아웃: #{e.message}"
  rescue => e
    raise Error, "Townin API 호출 실패: #{e.class}: #{e.message}"
  end
  private_class_method :request_with_key

  def self.parse_body(response)
    case response.code.to_i
    when 200..299
      JSON.parse(response.body || "{}")
    when 400
      raise BadRequest, extract_message(response)
    when 401, 403
      raise Unauthorized, "Townin API 인증 실패 (#{response.code}): CHOPD_API_KEY 확인"
    when 404
      raise NotFound, extract_message(response) || "Resource not found"
    when 500..599
      raise ServerError, "Townin 서버 에러 #{response.code}: #{extract_message(response)}"
    else
      raise Error, "Unexpected response #{response.code}: #{response.body}"
    end
  end
  private_class_method :parse_body

  def self.extract_message(response)
    JSON.parse(response.body || "{}").dig("error", "message") ||
      JSON.parse(response.body || "{}")["message"]
  rescue JSON::ParserError
    response.body
  end
  private_class_method :extract_message
end
