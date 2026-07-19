# frozen_string_literal: true

# ISS-401: IdentityProbe 결과 레코드.
# Orchestrator가 채우고, /welcome/probe 위자드가 읽는다.
class IdentityProbe < ApplicationRecord
  STATUSES = %w[pending in_progress completed failed expired rejected].freeze
  USER_DECISIONS = %w[accepted partial rejected].freeze

  belongs_to :member

  # SQLite 환경이므로 JSON 직렬화. Rails 7.1+ coder 지정 사용.
  serialize :identity,        coder: JSON
  serialize :sources_queried, type: Array, coder: JSON
  serialize :sources_hit,     type: Array, coder: JSON
  serialize :raw_signals,     type: Array, coder: JSON
  serialize :step_payloads,   coder: JSON

  validates :status, inclusion: { in: STATUSES }
  validates :user_decision, inclusion: { in: USER_DECISIONS }, allow_nil: true

  scope :pending,    -> { where(status: "pending") }
  scope :completed,  -> { where(status: "completed") }
  scope :expired,    -> { where("expires_at < ?", Time.current) }
  scope :needs_purge, lambda {
    purge_days = defined?(::IdentityProbeConfig::VALUES) ? ::IdentityProbeConfig::VALUES.fetch(:purge_raw_days, 30) : 30
    where("created_at < ?", purge_days.days.ago).where(raw_purged_at: nil)
  }

  before_create :set_expiry
  after_create_commit :log_creation

  # 위자드 스텝 전진 (S0~S6). payload_hash는 스텝별 사용자 입력/결과 저장.
  def advance_step!(step, payload_hash = {})
    step = step.to_i
    payloads = step_payloads.is_a?(Hash) ? step_payloads.dup : {}
    payloads["s#{step}"] = payload_hash
    update!(last_step: step, step_payloads: payloads)
  end

  # 회원 결정 확정 (accepted/partial/rejected).
  def finalize!(decision)
    decision = decision.to_s
    raise ArgumentError, "invalid decision #{decision}" unless USER_DECISIONS.include?(decision)
    update!(
      user_decision: decision,
      decided_at: Time.current,
      status: decision == "rejected" ? "rejected" : "completed",
    )
  end

  # PIPA: raw_signals만 비우고 구조화 결과(identity)는 유지.
  def purge_raw_signals!
    update!(raw_signals: [], raw_purged_at: Time.current)
  end

  private

  def set_expiry
    expiry_hours = (defined?(::IdentityProbeConfig::VALUES) && ::IdentityProbeConfig::VALUES[:expiry_hours]) || 24
    self.expires_at ||= Time.current + expiry_hours.hours
  end

  def log_creation
    Rails.logger.info("[IdentityProbe] created id=#{id} member_id=#{member_id} status=#{status}")
  end
end
