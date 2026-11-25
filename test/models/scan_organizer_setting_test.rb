require "test_helper"

class ScanOrganizerSettingTest < ActiveSupport::TestCase
  test "encrypts the key at rest and omits it from inspection and JSON" do
    member = Member.create!(name: "스캔 회원", email: "scan-settings@example.com", slug: "scan-settings", password: "password1234")
    key = "secret-api-key-test-1234"
    setting = member.create_scan_organizer_setting!(ai_provider: "gemini", ai_api_key: key)

    raw = ScanOrganizerSetting.connection.select_value("SELECT ai_api_key FROM scan_organizer_settings WHERE id = #{setting.id}")
    assert raw.present?
    refute_includes raw, key
    refute_includes setting.inspect, key
    refute_includes setting.to_json, key
    refute_includes setting.as_json(only: :ai_api_key), "ai_api_key"
    assert_equal key, setting.reload.ai_api_key
    assert_equal "1234", setting.ai_key_last4
  end

  test "shows a suffix only for keys of at least twelve characters" do
    setting = ScanOrganizerSetting.new(ai_api_key: "123456789012")
    assert_equal "9012", setting.ai_key_last4

    setting.ai_api_key = "12345678901"
    assert_nil setting.ai_key_last4
    assert_nil setting[:ai_key_last4]
  end

  test "validates the cloud and frequency" do
    setting = ScanOrganizerSetting.new(member: Member.new)
    assert setting.valid?

    setting.assign_attributes(cloud_provider: "onedrive", run_frequency: "monthly")
    refute setting.valid?
    assert setting.errors.of_kind?(:cloud_provider, :inclusion)
    assert setting.errors.of_kind?(:run_frequency, :inclusion)
  end
end
