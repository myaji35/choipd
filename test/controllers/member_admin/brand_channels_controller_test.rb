require "test_helper"

class MemberAdmin::BrandChannelsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @member = Member.create!(name: "채널 회원", email: "member-channel@example.com", slug: "member-channel",
      status: "approved", password: "password1234", password_confirmation: "password1234")
    @other_member = Member.create!(name: "다른 회원", email: "other-channel@example.com", slug: "other-channel")
    @brand = Brand.create!(name: "내 채널 브랜드", member_id: @member.id)
    @channel = @brand.brand_channels.create!(platform: "naver_blog", account_handle: "my-channel", credential_ref: "private-label")
    @other_channel = Brand.create!(name: "다른 채널 브랜드", member_id: @other_member.id)
      .brand_channels.create!(platform: "other", account_handle: "other-channel-handle")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "redirects anonymous channel requests to the member login" do
    reset!

    get edit_slug_admin_brand_brand_channel_path(slug: @member.slug, id: @channel.id)
    assert_redirected_to login_member_path(slug: @member.slug)

    patch slug_admin_brand_brand_channel_path(slug: @member.slug, id: @channel.id),
      params: { brand_channel: { account_handle: "forbidden" } }
    assert_redirected_to login_member_path(slug: @member.slug)
    assert_equal "my-channel", @channel.reload.account_handle
  end

  test "returns 404 for an admin session without the owning member session" do
    reset!
    admin = AdminUser.create!(email: "member-channel-admin@example.com", password: "password1234", role: "admin")
    sign_in admin

    get edit_slug_admin_brand_brand_channel_path(slug: @member.slug, id: @channel.id)
    assert_response :not_found
  end

  test "lists owned channels and excludes credential labels from the list and edit form" do
    get slug_admin_brand_path(slug: @member.slug)
    assert_response :success
    assert_includes response.body, "my-channel"
    assert_not_includes response.body, "other-channel-handle"
    assert_not_includes response.body, "private-label"

    get edit_slug_admin_brand_brand_channel_path(slug: @member.slug, id: @channel.id)
    assert_response :success
    assert_select 'input[type="checkbox"][name="brand_channel[delegation_consent]"]'
    assert_select 'input[name="brand_channel[credential_ref]"], input[type="password"]', count: 0
    assert_not_includes response.body, "private-label"
  end

  test "updates allowed fields, preserves consent on subsequent edits and supports withdrawal" do
    path = slug_admin_brand_brand_channel_path(slug: @member.slug, id: @channel.id)
    account = SnsAccount.create!(member: @member, platform: "facebook", account_name: "내 페이지")
    patch path, params: { brand_channel: {
      account_handle: "updated-channel", profile_url: "https://example.com/channel", delegation_consent: "1",
      credential_ref: "replacement", connection_method: "manual", session_status: "connected", sns_account_id: account.id,
      platform: "other", brand_id: @other_channel.brand_id
    } }
    assert_redirected_to slug_admin_brand_path(slug: @member.slug)
    @channel.reload
    assert_equal "updated-channel", @channel.account_handle
    assert_equal "https://example.com/channel", @channel.profile_url
    assert_equal "private-label", @channel.credential_ref
    assert_equal "ego_session", @channel.connection_method
    assert_equal "unknown", @channel.session_status
    assert_nil @channel.sns_account_id
    assert_equal "naver_blog", @channel.platform
    assert_equal @brand.id, @channel.brand_id
    assert @channel.delegated?

    consent_at = @channel.delegation_consent_at
    patch path, params: { brand_channel: { delegation_consent: "1" } }
    assert_equal consent_at, @channel.reload.delegation_consent_at

    patch path, params: { brand_channel: { delegation_consent: "0" } }
    assert_not @channel.reload.delegated?
    follow_redirect!
    assert_includes response.body, "공유한 계정 비밀번호를 변경해 주세요."
  end

  test "returns 404 for foreign channels under either member slug" do
    [ @member.slug, @other_member.slug ].each do |slug|
      get edit_slug_admin_brand_brand_channel_path(slug: slug, id: @other_channel.id)
      assert_response :not_found
      patch slug_admin_brand_brand_channel_path(slug: slug, id: @other_channel.id),
        params: { brand_channel: { account_handle: "forbidden" } }
      assert_response :not_found
    end
    assert_equal "other-channel-handle", @other_channel.reload.account_handle
  end
end
