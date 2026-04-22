# Townin 파트너 활동 스냅샷 페처 (ISS-330, 2026-04-23)
#
# 회원의 "지금 진짜 일하고 있다"는 증거를 Townin으로부터 가져온다.
# 부러움 유발의 핵심: 숫자가 아닌 "살아 있는 리듬".
#
# Townin 쪽 엔드포인트:
#   GET /api/v1/partners/:partner_id/impd-snapshot
#
# 응답 스펙:
#   { monthly_revenue, monthly_revenue_delta_pct,
#     customer_count, customer_delta,
#     issues_resolved_week, active_days_streak,
#     rating, review_count,
#     last_activity_at,
#     recent_activities: [{ type, title, at }],
#     tenure_months }
#
# Townin이 아직 이 엔드포인트를 안 내린 상태에서도 우리 UI는 망가지지 않는다.
# 관리자가 /admin/members/:id/stats 에서 직접 JSON 붙여넣어도 동일하게 작동.
class TowninSnapshotFetcher
  TIMEOUT = 8 # seconds
  CACHE_HOURS = 6

  def self.fetch!(member, force: false)
    return unless member.partner_active? && member.towningraph_user_id.present?
    return if !force && member.stats_fresh?

    snapshot = fetch_from_townin(member) || {}
    return if snapshot.empty?

    member.update!(
      townin_stats_json: snapshot.to_json,
      stats_synced_at: Time.current,
    )
    snapshot
  rescue StandardError => e
    Rails.logger.error "[TowninSnapshotFetcher] #{member.slug}: #{e.class}: #{e.message}"
    nil
  end

  # Townin API가 엔드포인트를 아직 노출하지 않은 경우 nil 반환 → UI가 graceful degrade.
  def self.fetch_from_townin(member)
    return nil unless TowninClient.enabled?

    require "net/http"
    require "uri"
    require "json"

    uri = URI.parse("#{TowninClient.base_url}/partners/#{member.towningraph_user_id}/impd-snapshot")
    req = Net::HTTP::Get.new(uri)
    req["X-API-Key"] = TowninClient.api_key
    req["Accept"] = "application/json"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.read_timeout = TIMEOUT
    http.open_timeout = TIMEOUT

    res = http.request(req)
    case res.code.to_i
    when 200..299
      JSON.parse(res.body || "{}")
    when 404
      Rails.logger.info "[TowninSnapshotFetcher] endpoint not yet available for #{member.slug}"
      nil
    else
      Rails.logger.warn "[TowninSnapshotFetcher] HTTP #{res.code} for #{member.slug}"
      nil
    end
  rescue Net::OpenTimeout, Net::ReadTimeout
    nil
  rescue StandardError => e
    Rails.logger.error "[TowninSnapshotFetcher.fetch_from_townin] #{e.class}: #{e.message}"
    nil
  end
end
