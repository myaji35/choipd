require "test_helper"

class Admin::BrandChannelsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = AdminUser.create!(email: "channel-admin@example.com", password: "password1234", role: "admin")
    @brand = Brand.create!(name: "운영 브랜드", tenant_id: 2)
  end

  test "requires admin authentication" do
    get new_admin_brand_brand_channel_path(@brand)
    assert_redirected_to new_admin_user_session_path
  end

  test "creates, lists, edits and deletes a brand channel" do
    sign_in @admin
    get new_admin_brand_brand_channel_path(@brand)
    assert_response :success
    assert_select 'input[type="password"]', count: 0

    assert_difference("BrandChannel.count") do
      post admin_brand_brand_channels_path(@brand), params: {
        brand_channel: { platform: "naver_blog", account_handle: "운영계정", session_status: "logged_out",
                         credential_ref: "impd-admin-label", delegation_consent_at: Time.current }
      }
    end
    assert_redirected_to admin_brand_path(@brand)
    channel = @brand.brand_channels.first
    assert_equal "ego_session", channel.connection_method
    assert_equal @brand.tenant_id, channel.tenant_id
    assert_not channel.delegated?

    follow_redirect!
    assert_select ".bg-red-100.text-red-700", text: "로그인 필요"

    get edit_admin_brand_brand_channel_path(@brand, channel)
    assert_response :success
    assert_select 'input[name="brand_channel[credential_ref]"][value="impd-admin-label"]'

    patch admin_brand_brand_channel_path(@brand, channel), params: { brand_channel: { session_status: "error" } }
    assert_redirected_to admin_brand_path(@brand)
    follow_redirect!
    assert_select ".bg-red-100.text-red-700", text: "오류"

    assert_difference("BrandChannel.count", -1) { delete admin_brand_brand_channel_path(@brand, channel) }
    assert_response :see_other
  end

  test "rejects a channel under the wrong brand" do
    sign_in @admin
    channel = Brand.create!(name: "다른 운영 브랜드").brand_channels.create!(platform: "other")
    patch admin_brand_brand_channel_path(@brand, channel), params: { brand_channel: { account_handle: "변경" } }
    assert_response :not_found
    assert_nil channel.reload.account_handle
  end
end
