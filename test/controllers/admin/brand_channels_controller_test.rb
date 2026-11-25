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
                         credential_ref: "impd-admin-label", ego_server_name: "m6.brand", delegation_consent_at: Time.current }
      }
    end
    assert_redirected_to admin_brand_path(@brand)
    channel = @brand.brand_channels.first
    assert_equal "ego_session", channel.connection_method
    assert_equal @brand.tenant_id, channel.tenant_id
    assert_not channel.delegated?
    assert_equal "m6.brand", channel.ego_server_name

    follow_redirect!
    assert_select ".bg-red-100.text-red-700", text: "로그인 필요"
    assert_select "tr td", text: "동의 대기"

    get edit_admin_brand_brand_channel_path(@brand, channel)
    assert_response :success
    assert_select 'input[name="brand_channel[credential_ref]"][value="impd-admin-label"]'
    assert_select 'input[name="brand_channel[ego_server_name]"][value="m6.brand"]'

    patch admin_brand_brand_channel_path(@brand, channel), params: { brand_channel: { session_status: "error" } }
    assert_redirected_to admin_brand_path(@brand)
    follow_redirect!
    assert_select ".bg-red-100.text-red-700", text: "오류"

    assert_difference("BrandChannel.count", -1) { delete admin_brand_brand_channel_path(@brand, channel) }
    assert_response :see_other
  end

  test "채널 폼은 기본 칸을 먼저 보여 주고 연결 설정은 접어 둔다" do
    sign_in @admin

    get new_admin_brand_brand_channel_path(@brand)
    assert_response :success
    assert_select "a[href=?]", admin_brand_path(@brand), text: /채널 목록/
    assert_select "label", text: "계정 이름(핸들)"
    assert_select "details:not([open]) input[name='brand_channel[credential_ref]']"
    assert_select "details summary", text: /연결 설정/

    post admin_brand_brand_channels_path(@brand), params: {
      brand_channel: { platform: "naver_blog", connection_method: "" }
    }
    assert_redirected_to admin_brand_path(@brand)
    channel = @brand.brand_channels.sole
    assert_equal "ego_session", channel.connection_method

    get edit_admin_brand_brand_channel_path(@brand, channel)
    assert_response :success
    assert_select "details[open] input[name='brand_channel[credential_ref]']"

    post admin_brand_brand_channels_path(@brand), params: {
      brand_channel: { platform: "other", credential_ref: "invalid label" }
    }
    assert_response :unprocessable_entity
    assert_select "details[open] input[name='brand_channel[credential_ref]'][value='invalid label']"
  end

  test "회원 브랜드에서는 대행 등록 화면으로 가는 링크를 보여 준다" do
    sign_in @admin
    member = Member.create!(name: "브랜드 회원", email: "brand-member@example.test", slug: "brand-member")
    brand = member.ensure_personal_brand!
    link_text = "이 회원 계정·채널 대행 등록"

    [admin_brand_path(brand), new_admin_brand_brand_channel_path(brand)].each do |path|
      get path
      assert_response :success
      assert_select "a[href=?]", pd_member_path(member), text: link_text
    end
    [admin_brand_path(@brand), new_admin_brand_brand_channel_path(@brand)].each do |path|
      get path
      assert_response :success
      assert_select "a", text: link_text, count: 0
    end
  end

  test "rejects a channel under the wrong brand" do
    sign_in @admin
    channel = Brand.create!(name: "다른 운영 브랜드").brand_channels.create!(platform: "other")
    patch admin_brand_brand_channel_path(@brand, channel), params: { brand_channel: { account_handle: "변경" } }
    assert_response :not_found
    assert_nil channel.reload.account_handle
  end
end
