require "digest"

# SNS 액세스 토큰 등 민감정보 암호화. 프로덕션은 환경변수로 키 주입, 없으면 secret_key_base 파생(개발 폴백).
Rails.application.config.after_initialize do
  enc = Rails.application.config.active_record.encryption
  base = Rails.application.secret_key_base.to_s
  enc.primary_key ||= ENV["AR_ENCRYPTION_PRIMARY_KEY"].presence || Digest::SHA256.hexdigest("primary:#{base}")
  enc.deterministic_key ||= ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"].presence || Digest::SHA256.hexdigest("deterministic:#{base}")
  enc.key_derivation_salt ||= ENV["AR_ENCRYPTION_SALT"].presence || Digest::SHA256.hexdigest("salt:#{base}")
end
