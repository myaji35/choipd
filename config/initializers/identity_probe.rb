# frozen_string_literal: true

# ISS-401: IdentityProbe 엔진 설정.
# ENV 키 집중 관리 + 구성 상수.
#
# NOTE: IdentityProbe는 ActiveRecord 모델(클래스)이므로 여기서 module로 재정의하면 충돌한다.
# 설정은 별도 네임스페이스(IdentityProbeConfig)로 분리.
module IdentityProbeConfig
  VALUES = {
    timeout_sec: 15,      # 파이프라인 전체 예산
    expiry_hours: 24,     # probe 결과 만료
    purge_raw_days: 30,   # raw_signals 자동 퍼지 (PIPA)
  }.freeze
end

Rails.application.config.after_initialize do
  keys = {
    anthropic:      ENV["ANTHROPIC_API_KEY"].to_s.strip,
    google_cse_key: ENV["GOOGLE_CSE_KEY"].to_s.strip,
    google_cse_id:  ENV["GOOGLE_CSE_ID"].to_s.strip,
    naver_id:       ENV["NAVER_CLIENT_ID"].to_s.strip,
    naver_secret:   ENV["NAVER_CLIENT_SECRET"].to_s.strip,
  }

  presence = keys.transform_values { |v| v.empty? ? "missing" : "present" }
  mock_mode = keys[:anthropic].empty?

  Rails.logger.info(
    "[IdentityProbe] boot — mock_mode=#{mock_mode} " \
    "anthropic=#{presence[:anthropic]} google_cse=#{presence[:google_cse_key]}/#{presence[:google_cse_id]} " \
    "naver=#{presence[:naver_id]}/#{presence[:naver_secret]}"
  )
end
