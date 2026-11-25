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

  test "등록 전 플랫폼에는 같은 테넌트의 미연결 계정만 표시한다" do
    account = ProfileAccount.create!(platform: "linkedin", display_name: "점검 계정",
      login_id: "checked@example.test", session_status: "logged_in", tenant_id: @member.tenant_id)
    other = Member.create!(name: "다른 회원", email: "linked-other@example.test", slug: "linked-other")
    linked = other.profile_accounts.create!(platform: "linkedin", display_name: "연결된 계정")
    foreign = ProfileAccount.create!(platform: "linkedin", display_name: "다른 테넌트 계정", tenant_id: 2)
    sign_in @pd

    get pd_member_path(@member)

    assert_select "#accounts li p", text: "점검 계정 · checked@example.test · 로그인됨"
    assert_select "#accounts form[action=?][method=post]", pd_profile_account_path(account) do
      assert_select "input[name='_method'][value=patch]"
      assert_select "input[name='profile_account[member_id]'][value=?]", @member.id.to_s
      assert_select "input[name=link][value=1]"
      assert_select "button", text: "이 회원에 연결"
    end
    [linked, foreign].each do |excluded|
      assert_select "#accounts li", text: /#{excluded.display_name}/, count: 0
      assert_select "#accounts form[action=?]", pd_profile_account_path(excluded), count: 0
    end

    @member.profile_accounts.create!(platform: "linkedin", display_name: "회원의 LinkedIn")
    get pd_member_path(@member)

    assert_select "#accounts form[action=?]", pd_profile_account_path(account), count: 0
  end

  test "미연결 계정은 플랫폼별로 5개까지만 표시하고 목록을 안내한다" do
    6.times do |index|
      ProfileAccount.create!(platform: "linkedin", display_name: "점검 계정 #{index + 1}")
    end
    sign_in @pd

    get pd_member_path(@member)

    assert_select "#accounts button", text: "이 회원에 연결", count: 5
    assert_select "#accounts li", text: /점검 계정 6/, count: 0
    assert_select "#accounts a[href=?]", pd_profile_accounts_path, text: "인물정보 계정"
  end

  test "운영자에게만 대행 등록 화면에 운영자 회원 상세 링크를 표시한다" do
    sign_in @pd
    get pd_member_path(@member)
    assert_select "a[href=?]", admin_member_path(@member), count: 0

    sign_out @pd
    sign_in AdminUser.create!(email: "admin-members@example.test", password: "password123", role: "admin")
    get pd_member_path(@member)
    assert_select "header a[href=?]", admin_member_path(@member), text: "운영자 회원 상세"
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
