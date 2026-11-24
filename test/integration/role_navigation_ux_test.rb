require "test_helper"

class RoleNavigationUxTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "PD 계정이 운영자 화면에 접근하면 안내와 함께 PD 대시보드로 이동한다" do
    sign_in staff_user("pd")

    get admin_root_path

    assert_redirected_to pd_root_path
    follow_redirect!
    assert_includes response.body, "PD 계정은 운영자 화면에 들어갈 수 없어 PD 대시보드로 이동했습니다."
  end

  test "PD 화면의 운영자 링크는 운영자 계정에만 표시한다" do
    pd = staff_user("pd")
    sign_in pd

    get pd_root_path
    assert_response :success
    assert_select "a[href=?]", admin_root_path, count: 0

    sign_out pd
    sign_in staff_user("admin")

    get pd_root_path
    assert_response :success
    assert_select ".pd-header-links a[href=?]", admin_root_path, text: "Admin"
    assert_select ".pd-mobile-links a[href=?]", admin_root_path, text: "Admin"
  end

  test "운영자 대시보드의 승인 대기 카드는 실제 회원 수를 표시한다" do
    create_member(status: "pending_approval")
    create_member(status: "approved")
    sign_in staff_user("admin")

    get admin_root_path

    assert_response :success
    assert_select "a[href=?] p.text-3xl", admin_members_path(status: "pending_approval"),
      text: Member.by_status("pending_approval").count.to_s, count: 1
  end

  test "운영자가 회원 화면에 들어가면 대리 접속 띠를 표시한다" do
    member = create_member(status: "approved")
    sign_in staff_user("admin")

    get slug_admin_dashboard_path(slug: member.slug)

    assert_response :success
    assert_select ".admin-impersonation-banner", text: /운영자 권한으로 #{member.name}님/
    assert_select ".admin-impersonation-banner a[href=?]", admin_member_path(member), text: "운영자 화면으로 돌아가기"
    assert_select "form[action=?]", logout_member_path(slug: member.slug), count: 0
  end

  test "PD가 회원 화면에 들어가면 대리 접속 띠에서 PD 대시보드로 돌아갈 수 있다" do
    member = create_member(status: "approved")
    sign_in staff_user("pd")

    get slug_admin_dashboard_path(slug: member.slug)

    assert_response :success
    assert_select ".admin-impersonation-banner", text: /PD 권한으로 #{member.name}님/
    assert_select ".admin-impersonation-banner a[href=?]", pd_root_path, text: "PD 대시보드로 돌아가기"
    assert_select "a[href=?]", admin_member_path(member), count: 0
  end

  test "회원만 로그인하면 대리 접속 띠를 표시하지 않는다" do
    member = create_member(status: "approved")
    post "/auth/login", params: { email: member.email, password: "password1234" }

    get slug_admin_dashboard_path(slug: member.slug)

    assert_response :success
    assert_select ".admin-impersonation-banner", count: 0
    assert_select "form[action=?]", logout_member_path(slug: member.slug), count: 2
  end

  test "회원 목록은 상태를 한국어로 표시하고 회원 관리 메뉴만 활성화한다" do
    create_member(status: "pending_approval")
    sign_in staff_user("admin")

    get admin_members_path

    assert_response :success
    assert_select "tbody td span", text: "승인 대기"
    assert_select "tbody td span", text: "pending_approval", count: 0
    assert_select "nav a[href=?].bg-primary", admin_root_path, count: 0
    assert_select "nav a[href=?].bg-primary", admin_members_path, count: 1
  end

  test "거부된 회원 상세에 다시 승인 버튼과 거부 사유를 표시한다" do
    member = create_member(status: "rejected")
    member.update!(rejection_reason: "신청 정보 확인 필요")
    sign_in staff_user("admin")

    get admin_member_path(member)

    assert_response :success
    assert_select "form[action=?][method=post] button", approve_admin_member_path(member), text: "다시 승인"
    assert_select "p", text: "거부 사유: 신청 정보 확인 필요"
  end

  test "승인 대기 회원 상세에 로그인·편집 가능 여부와 공개 상태를 표시한다" do
    member = create_member(status: "pending_approval")
    sign_in staff_user("admin")

    get admin_member_path(member)

    assert_response :success
    assert_select "li", text: /로그인·내 페이지 편집 —\s*불가/
    assert_select "li", text: /공개 페이지 \(\/#{member.slug}\) 노출 —\s*비공개/
  end

  test "운영자 모바일 메뉴 버튼의 aria-controls가 사이드바를 가리킨다" do
    sign_in staff_user("admin")

    get admin_root_path

    assert_response :success
    buttons = assert_select "button.admin-menu-button[aria-controls][aria-expanded=false]", count: 1
    assert_select "aside[id=?][data-admin-menu]", buttons.first["aria-controls"], count: 1
  end

  test "로그인한 운영자가 로그인 화면을 다시 열면 한국어로 안내한다" do
    sign_in staff_user("admin")

    get "/admin/login"

    assert_redirected_to admin_root_path
    follow_redirect!
    assert_includes response.body, "이미 로그인되어 있습니다."
  end

  private

  def staff_user(role)
    AdminUser.create!(email: "role-navigation-#{role}@example.test", password: "password123", role: role)
  end

  def create_member(status:)
    slug = "role-ux-#{status.tr('_', '-')}"
    Member.create!(name: "테스트 회원", email: "#{slug}@example.test", slug: slug, status: status,
      business_type: "individual", profession: "custom", password: "password1234", password_confirmation: "password1234")
  end
end
