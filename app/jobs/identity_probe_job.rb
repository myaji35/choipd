# frozen_string_literal: true

require "timeout"

# ISS-401: 가입 직후 Member의 identity를 공개 웹/SNS에서 탐색한다.
# Timeout 15초 예산. 실패 시 status="failed" + 재시도 1회.
class IdentityProbeJob < ApplicationJob
  # solid_queue에 identity_probe 큐가 없으면 default로 떨어진다.
  queue_as :identity_probe

  retry_on StandardError, wait: 5.seconds, attempts: 2

  def perform(member_id)
    member = Member.find_by(id: member_id)
    unless member
      Rails.logger.warn("[IdentityProbeJob] member not found id=#{member_id}")
      return
    end

    budget = (defined?(::IdentityProbeConfig::VALUES) && ::IdentityProbeConfig::VALUES[:timeout_sec]) || 15

    begin
      Timeout.timeout(budget + 5) do
        ::IdentityProbeEngine::Orchestrator.call(member)
      end
    rescue => e
      Rails.logger.error("[IdentityProbeJob] failed member_id=#{member_id} error=#{e.class}: #{e.message}")
      probe = ::IdentityProbe.where(member_id: member_id).order(created_at: :desc).first
      if probe
        probe.update(status: "failed", identity: (probe.identity || {}).merge("error" => "#{e.class}: #{e.message.to_s[0, 200]}"))
      end
      raise
    end
  end
end
