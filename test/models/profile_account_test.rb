require "test_helper"

class ProfileAccountTest < ActiveSupport::TestCase
  test "validations and labels" do
    account = ProfileAccount.new(platform: "naver_people", display_name: "가상 인물")
    assert account.valid?
    assert_equal "네이버 인물정보", account.platform_label
    assert_equal "미점검", account.session_status_label
    account.platform = "invalid"
    account.session_status = "invalid"
    account.display_name = ""
    assert_not account.valid?
    assert_equal [ :display_name, :platform, :session_status ], account.errors.attribute_names.sort
  end

  test "external id is unique per tenant and platform and may be blank" do
    ProfileAccount.create!(platform: "linkedin", display_name: "가상 인물", external_id: "fake-id")
    duplicate = ProfileAccount.new(platform: "linkedin", display_name: "다른 인물", external_id: "fake-id")
    assert_not duplicate.valid?
    duplicate.tenant_id = 2
    assert duplicate.valid?
    duplicate.tenant_id = 1
    duplicate.platform = "naver_people"
    assert duplicate.valid?
    duplicate.platform = "linkedin"
    duplicate.external_id = nil
    assert duplicate.valid?
  end
end
