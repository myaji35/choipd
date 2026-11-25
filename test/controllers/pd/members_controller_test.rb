require "test_helper"

class Pd::MembersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @pd = AdminUser.create!(email: "pd-members@example.test", password: "password123", role: "pd")
    @member = Member.create!(name: "대행 등록 회원", email: "pd-member@example.test", slug: "pd-member")
  end

  test "로그인이 필요하다" do
    get pd_members_path
    assert_redirected_to new_admin_user_session_path
    get pd_member_path(@member)
    assert_redirected_to new_admin_user_session_path
  end

  test "PD가 회원 목록을 검색할 수 있다" do
    other = Member.create!(name: "다른 회원", email: "pd-other@example.test", slug: "pd-other")
    sign_in @pd

    get pd_members_path
    assert_response :ok
    assert_select "h1", text: "회원 대행 등록"
    assert_select "li strong", text: @member.name
    assert_select "a[href=?]", pd_member_path(@member), text: "등록·확인"
    assert_select "a[href=?]", pd_member_path(other), text: "등록·확인"

    get pd_members_path, params: { q: @member.email }
    assert_response :ok
    assert_select "a[href=?]", pd_member_path(@member), text: "등록·확인"
    assert_select "a[href=?]", pd_member_path(other), count: 0
  end

  test "계정과 채널이 없는 회원의 플랫폼별 등록 링크를 보여 준다" do
    sign_in @pd
    get pd_member_path(@member)

    assert_response :ok
    assert_select "#accounts a", text: "계정 등록", count: 2
    ProfileAccount::PLATFORMS.each_key do |platform|
      assert_select "a[href=?]", new_pd_profile_account_path(member_id: @member.id, platform: platform), text: "계정 등록"
    end
    assert_select "#channels a", text: "채널 등록", count: 3
    MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.each_key do |platform|
      assert_select "a[href=?]", new_pd_member_channel_path(@member, platform: platform), text: "채널 등록"
    end
    assert_select "a[href=?]", slug_admin_dashboard_path(slug: @member.slug), text: "회원 화면에서 확인"
  end

  test "회원의 여러 브랜드에 등록된 채널을 개인 브랜드부터 보여 주고 동의 상태를 표시한다" do
    brand = @member.brands.create!(name: "브랜드")
    waiting = brand.brand_channels.create!(platform: "naver_blog", account_handle: "waiting")
    personal = @member.ensure_personal_brand!
    consented = personal.brand_channels.create!(
      platform: "naver_blog", account_handle: "consented", delegation_consent_at: Time.utc(2026, 11, 24, 16)
    )
    sign_in @pd

    get pd_member_path(@member)
    assert_response :ok
    assert_select "#channels li", text: /운영 위탁 동의 대기/ do
      assert_select "a[href=?]", edit_pd_member_channel_path(@member, waiting)
    end
    assert_select "#channels li", text: /운영 위탁 동의함 · 2026\.11\.25/ do
      assert_select "a[href=?]", edit_pd_member_channel_path(@member, consented)
    end
    assert_select "#channels li:first-child", text: /consented/
  end
end
