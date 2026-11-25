require "test_helper"

class Pd::MemberChannelsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @pd = AdminUser.create!(email: "pd-channels@example.test", password: "password123", role: "pd")
    @member = Member.create!(name: "채널 등록 회원", email: "pd-channel-member@example.test", slug: "pd-channel-member")
  end

  test "PD가 개인 브랜드 없이 시작해 채널을 등록하고 회원 대시보드에서 확인한다" do
    sign_in @pd
    get new_pd_member_channel_path(@member, platform: "naver_blog")
    assert_response :ok
    assert_select "select[name='brand_channel[platform]'] option[value=naver_blog][selected]"
    assert_select "input[name^='brand_channel'], select[name^='brand_channel'], textarea[name^='brand_channel']", count: 4

    assert_difference({ "Brand.where(personal: true).count" => 1, "BrandChannel.count" => 1 }) do
      post pd_member_channels_path(@member), params: { brand_channel: { platform: "naver_blog", account_handle: "new-blog" } }
    end
    channel = @member.personal_brand.brand_channels.sole
    assert_equal BrandChannel::DEFAULT_CONNECTION_METHODS.fetch("naver_blog"), channel.connection_method
    assert_nil channel.delegation_consent_at
    assert_redirected_to pd_member_path(@member, anchor: "channels")
    follow_redirect!
    assert_includes response.body, "네이버 블로그 채널을 등록했습니다. 회원 화면에 바로 보입니다."

    get slug_admin_dashboard_path(slug: @member.slug)
    assert_response :ok
    assert_select "#channel-status h3", text: "네이버 블로그 등록 전", count: 0
    assert_select "#channel-status article", text: /네이버 블로그.*준비 중/m
  end

  test "운영자도 채널을 등록할 수 있고 허용된 필드만 저장한다" do
    sign_in AdminUser.create!(email: "staff-channels@example.test", password: "password123", role: "admin")

    post pd_member_channels_path(@member), params: { brand_channel: {
      platform: "instagram", account_handle: "my-photo", profile_url: "https://example.test/my-photo", notes: "등록 메모",
      credential_ref: "vault", ego_server_name: "ego", session_status: "connected", delegation_consent_at: Time.current,
      connection_method: "manual", sns_account_id: 123, profile_account_id: 456
    } }

    assert_redirected_to pd_member_path(@member, anchor: "channels")
    channel = @member.personal_brand.brand_channels.sole
    assert_equal "my-photo", channel.account_handle
    assert_equal "https://example.test/my-photo", channel.profile_url
    assert_equal "등록 메모", channel.notes
    assert_equal "oauth", channel.connection_method
    assert_equal "unknown", channel.session_status
    assert_nil channel.credential_ref
    assert_nil channel.ego_server_name
    assert_nil channel.sns_account_id
    assert_nil channel.profile_account_id
    assert_not channel.delegated?
  end

  test "허용되지 않은 플랫폼을 미리 선택하거나 등록하지 않는다" do
    sign_in @pd
    get new_pd_member_channel_path(@member, platform: "youtube")
    assert_response :ok
    assert_select "#brand_channel_platform option[selected]", count: 0
    assert_select "#brand_channel_platform option[value='']", text: "선택해 주세요"

    assert_no_difference [ "Brand.count", "BrandChannel.count" ] do
      post pd_member_channels_path(@member), params: { brand_channel: { platform: "youtube" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert] li", text: "채널 종류를 선택해 주세요."
  end

  test "유효하지 않은 채널 주소는 폼에 표시하고 개인 브랜드 생성도 되돌린다" do
    sign_in @pd

    assert_no_difference [ "Brand.count", "BrandChannel.count" ] do
      post pd_member_channels_path(@member), params: { brand_channel: { platform: "naver_blog", profile_url: "ftp://example.test" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert] li", text: "채널 주소는 http 또는 https 주소여야 합니다."
    assert_select "#brand_channel_platform option[value=naver_blog][selected]"
  end

  test "같은 종류의 채널이 다른 브랜드에 있어도 해당 수정 화면으로 이동한다" do
    channel = @member.brands.create!(name: "기존 브랜드").brand_channels.create!(platform: "naver_blog")
    sign_in @pd

    assert_no_difference [ "Brand.count", "BrandChannel.count" ] do
      post pd_member_channels_path(@member), params: { brand_channel: { platform: "naver_blog" } }
    end
    assert_redirected_to edit_pd_member_channel_path(@member, channel)
    follow_redirect!
    assert_includes response.body, "이미 등록된 채널이 있어 수정 화면으로 이동했습니다."
  end

  test "다른 회원의 채널은 수정할 수 없다" do
    other = Member.create!(name: "다른 회원", email: "other-pd-channel@example.test", slug: "other-pd-channel")
    channel = other.ensure_personal_brand!.brand_channels.create!(platform: "naver_blog")
    sign_in @pd

    get edit_pd_member_channel_path(@member, channel)
    assert_response :not_found

    sign_in @pd
    patch pd_member_channel_path(@member, channel), params: { brand_channel: { account_handle: "changed" } }
    assert_response :not_found
    assert_nil channel.reload.account_handle
  end

  test "채널 종류를 유지하면서 계정 이름을 수정한다" do
    channel = @member.ensure_personal_brand!.brand_channels.create!(platform: "naver_blog")
    sign_in @pd

    get edit_pd_member_channel_path(@member, channel)
    assert_response :ok
    assert_select "h1", text: "채널 수정"
    assert_select "select[name='brand_channel[platform]']", count: 0

    patch pd_member_channel_path(@member, channel), params: {
      brand_channel: { platform: "instagram", account_handle: "changed", delegation_consent_at: Time.current }
    }
    assert_redirected_to pd_member_path(@member, anchor: "channels")
    assert_equal "changed", channel.reload.account_handle
    assert_equal "naver_blog", channel.platform
    assert_not channel.delegated?
    follow_redirect!
    assert_includes response.body, "네이버 블로그 채널을 수정했습니다."
  end

  test "채널 폼과 저장에 로그인이 필요하다" do
    get new_pd_member_channel_path(@member)
    assert_redirected_to new_admin_user_session_path
    post pd_member_channels_path(@member), params: { brand_channel: { platform: "naver_blog" } }
    assert_redirected_to new_admin_user_session_path
  end
end
