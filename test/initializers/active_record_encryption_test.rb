require "test_helper"

class ActiveRecordEncryptionTest < ActiveSupport::TestCase
  test "encryption keys and salt are present" do
    config = ActiveRecord::Encryption.config

    assert_predicate config.primary_key, :present?
    assert_predicate config.deterministic_key, :present?
    assert_predicate config.key_derivation_salt, :present?
  end

  test "primary key is derived from secret key base when the environment override is absent" do
    if ENV["AR_ENCRYPTION_PRIMARY_KEY"].present? ||
        Rails.application.credentials.dig(:active_record_encryption, :primary_key).present? ||
        Rails.application.config.active_record.encryption.primary_key.present?
      skip "기본 키가 이미 설정됨"
    end

    expected = Digest::SHA256.hexdigest("primary:#{Rails.application.secret_key_base}")
    assert_equal expected, ActiveRecord::Encryption.config.primary_key
  end

  test "encryptor round trips plaintext" do
    encryptor = ActiveRecord::Encryption.encryptor
    plaintext = "encryption initializer test"

    ciphertext = encryptor.encrypt(plaintext)

    refute_equal plaintext, ciphertext
    assert_equal plaintext, encryptor.decrypt(ciphertext)
  end
end
