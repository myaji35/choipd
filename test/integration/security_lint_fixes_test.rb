require "test_helper"

class SecurityLintFixesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = AdminUser.create!(email: "security-#{SecureRandom.hex(4)}@example.com", password: "password1234", role: "admin")
    sign_in @admin
  end

  test "settings accepts known scalar keys and rejects unknown keys without writing" do
    patch "/api/v1/admin/settings", params: { settings: { site_name: "Example", site_description: "Description" } }
    assert_response :success
    assert_equal "Example", Setting.find_by!(key: "site_name").value

    patch "/api/v1/admin/settings", params: { settings: { site_name: "Changed", unexpected: "bad" } }
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "unexpected"
    assert_equal "Example", Setting.find_by!(key: "site_name").value
  end

  test "webhook events are escaped" do
    webhook = Webhook.create!(tenant_id: 1, name: "Test", url: "https://example.com", events: [ "<script>alert(1)</script>" ].to_json, secret: "secret", created_by: @admin.email)
    get admin_webhook_path(webhook)
    assert_response :success
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_no_match(/<script>alert\(1\)<\/script>/, response.body)
  end
end
