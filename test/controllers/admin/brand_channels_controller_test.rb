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
    assert_equal "운영계정", channel.account_handle
    assert_equal "https://blog.naver.com/%EC%9A%B4%EC%98%81%EA%B3%84%EC%A0%95", channel.profile_url
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

  test "운영자가 인스타그램 주소나 @이름을 입력하면 계정 이름과 기준 주소로 저장한다" do
    sign_in @admin
    url = "https://www.instagram.com/gagahoho_kang/"
    post admin_brand_brand_channels_path(@brand),
      params: { brand_channel: { platform: "instagram", account_handle: url, profile_url: "" } }
    assert_redirected_to admin_brand_path(@brand)
    channel = @brand.brand_channels.sole
    assert_equal "gagahoho_kang", channel.account_handle
    assert_equal url, channel.profile_url

    patch admin_brand_brand_channel_path(@brand, channel),
      params: { brand_channel: { account_handle: "@new_name", profile_url: url } }
    assert_redirected_to admin_brand_path(@brand)
    assert_equal "new_name", channel.reload.account_handle
    assert_equal "https://www.instagram.com/new_name/", channel.profile_url
  end

  test "운영자 채널 등록 실패 시 입력한 계정 이름과 빈 주소를 유지한다" do
    sign_in @admin
    post admin_brand_brand_channels_path(@brand), params: {
      brand_channel: { platform: "instagram", account_handle: "@new_name", profile_url: "", credential_ref: "invalid label" }
    }

    assert_response :unprocessable_entity
    assert_select "input[name='brand_channel[account_handle]'][value='@new_name']"
    assert_select "input[name='brand_channel[profile_url]']" do |fields|
      assert_equal "", fields.first["value"].to_s
    end
  end

  test "운영자가 빈 계정 이름으로 수정하면 기존 주소를 폼에 유지한다" do
    sign_in @admin
    url = "https://blog.naver.com/my-channel"
    channel = @brand.brand_channels.create!(platform: "naver_blog", account_handle: "my-channel", profile_url: url)
    patch admin_brand_brand_channel_path(@brand, channel),
      params: { brand_channel: { account_handle: "", profile_url: url } }

    assert_response :unprocessable_entity
    assert_select "input[name='brand_channel[profile_url]'][value=?]", url
    assert_select "input[name='brand_channel[account_handle]'][value='']"
    assert_equal "my-channel", channel.reload.account_handle
    assert_equal url, channel.profile_url
  end

  test "빈 네이버 블로그 계정 이름과 모델 오류를 함께 표시한다" do
    sign_in @admin
    assert_no_difference "BrandChannel.count" do
      post admin_brand_brand_channels_path(@brand), params: {
        brand_channel: { platform: "naver_blog", account_handle: "", profile_url: "", credential_ref: "invalid label" }
      }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert] li", text: "계정 이름을 적어 주세요. 채널 주소만 붙여 넣어도 됩니다."
    assert_select "[role=alert] li", text: /보관 위치 이름표에는/
  end

  test "유튜브와 기타 채널은 계정 이름 없이 등록할 수 있다" do
    sign_in @admin
    %w[youtube other].each do |platform|
      assert_difference "BrandChannel.count" do
        post admin_brand_brand_channels_path(@brand), params: { brand_channel: { platform: platform } }
      end
      assert_redirected_to admin_brand_path(@brand)
      assert @brand.brand_channels.find_by!(platform: platform).account_handle.blank?
    end
  end

  test "계정 이름이 비어 있는 옛 채널의 연결 상태만 수정할 수 있다" do
    sign_in @admin
    channel = @brand.brand_channels.create!(platform: "naver_blog")
    patch admin_brand_brand_channel_path(@brand, channel), params: { brand_channel: { session_status: "error" } }
    assert_redirected_to admin_brand_path(@brand)
    assert_equal "error", channel.reload.session_status
    assert_nil channel.account_handle
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
      brand_channel: { platform: "naver_blog", account_handle: "blog", connection_method: "" }
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
