require "openssl"
require "net/http"

class Webhook < ApplicationRecord
  has_many :webhook_logs, dependent: :destroy

  validates :name, :url, :events, :secret, :created_by, presence: true

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :active, -> { where(is_active: true) }
  scope :for_event, ->(e) { where("events LIKE ?", "%\"#{e}\"%") }

  def events_list
    JSON.parse(events || "[]") rescue []
  end

  def headers_hash
    JSON.parse(headers || "{}") rescue {}
  end

  def retry_config_hash
    JSON.parse(retry_config || '{"max_retries":3,"backoff":"exponential"}') rescue { "max_retries" => 3, "backoff" => "exponential" }
  end

  # 웹훅 송출 + HMAC 서명
  def dispatch!(event:, payload:)
    return unless is_active?
    return unless events_list.include?(event)

    body = payload.to_json
    sig = OpenSSL::HMAC.hexdigest("SHA256", secret, body)

    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["X-Impd-Signature"] = "sha256=#{sig}"
    req["X-Impd-Event"] = event
    headers_hash.each { |k, v| req[k] = v }
    req.body = body

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", read_timeout: 10) { |http| http.request(req) }

    log_status = res.code.to_i.between?(200, 299) ? "success" : "failed"
    webhook_logs.create!(
      tenant_id: tenant_id, event: event, payload: body,
      status: log_status, response_code: res.code.to_i, response_body: res.body[0, 1000]
    )
    increment!(log_status == "success" ? :success_count : :failure_count)
    update_column(:last_triggered_at, Time.current)
    res
  rescue StandardError => e
    webhook_logs.create!(tenant_id: tenant_id, event: event, payload: payload.to_json, status: "failed", error: e.message)
    increment!(:failure_count)
    raise
  end
end
