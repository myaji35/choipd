# frozen_string_literal: true

class LlmConfig < ApplicationRecord
  validates :purpose, presence: true, uniqueness: true
  validates :provider, :model, presence: true

  def self.for(purpose, default_model:)
    config = find_by(purpose: purpose, enabled: true)
    return config if config

    # 행이 없는 것과 운영자가 꺼둔 것을 구분해 남긴다 — 무음 폴백 금지.
    reason = exists?(purpose: purpose) ? "disabled" : "missing"
    Rails.logger.info("[LlmConfig] fallback purpose=#{purpose} model=#{default_model} reason=#{reason}")
    new(purpose: purpose, model: default_model, provider: "anthropic")
  rescue => e
    Rails.logger.warn("[LlmConfig] fallback purpose=#{purpose} model=#{default_model} error=#{e.class}: #{e.message}")
    new(purpose: purpose, model: default_model, provider: "anthropic")
  end
end
