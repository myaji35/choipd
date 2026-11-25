require "test_helper"

class ScanOrganizerSettingTest < ActiveSupport::TestCase
  test "encrypts credentials at rest and omits them from inspection and JSON" do
    member = Member.create!(name: "스캔 회원", email: "scan-settings@example.com", slug: "scan-settings", password: "password1234")
    key = "secret-api-key-test-1234"
    token = "secret-refresh-token-test-5678"
    setting = member.create_scan_organizer_setting!(ai_provider: "gemini", ai_api_key: key, cloud_refresh_token: token)

    { ai_api_key: key, cloud_refresh_token: token }.each do |column, secret|
      raw = ScanOrganizerSetting.connection.select_value("SELECT #{column} FROM scan_organizer_settings WHERE id = #{setting.id}")
      assert raw.present?
      refute_includes raw, secret
      refute_includes setting.inspect, secret
      refute_includes setting.to_json, secret
      refute_includes setting.as_json(only: column), column.to_s
      assert_equal secret, setting.reload.public_send(column)
    end
    assert_equal "1234", setting.ai_key_last4
  end

  test "shows a suffix only for keys of at least twelve characters" do
    setting = ScanOrganizerSetting.new(ai_api_key: "123456789012")
    assert_equal "9012", setting.ai_key_last4

    setting.ai_api_key = "12345678901"
    assert_nil setting.ai_key_last4
    assert_nil setting[:ai_key_last4]
  end
end
