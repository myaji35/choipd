require "digest"

# SNS 액세스 토큰 등 민감정보 암호화. 프로덕션은 환경변수로 키 주입, 없으면 secret_key_base 파생(개발 폴백).
ActiveSupport.on_load(:active_record_encryption) do
  enc = ActiveRecord::Encryption.config
  base = Rails.application.secret_key_base.to_s
  fallbacks = {
    primary_key: [ "AR_ENCRYPTION_PRIMARY_KEY", "primary:#{base}" ],
    deterministic_key: [ "AR_ENCRYPTION_DETERMINISTIC_KEY", "deterministic:#{base}" ],
    key_derivation_salt: [ "AR_ENCRYPTION_SALT", "salt:#{base}" ]
  }

  filled = false
  fallbacks.each do |key, (env_name, seed)|
    next if enc.public_send("has_#{key}?")

    enc.public_send("#{key}=", ENV[env_name].presence || Digest::SHA256.hexdigest(seed))
    filled = true
  end

  ActiveRecord::Encryption.reset_default_context if filled
end
