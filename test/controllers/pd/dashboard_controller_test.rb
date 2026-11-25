require "test_helper"

class Pd::DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "PD 홈에 등록과 동의를 기다리는 회원 수와 필터 링크가 표시된다" do
    sign_in AdminUser.create!(email: "pd-dashboard@example.test", password: "password123", role: "pd")
    member = Member.create!(name: "동의 대기 회원", email: "waiting@example.test", slug: "waiting")
    brand = member.ensure_personal_brand!
    brand.brand_channels.create!(platform: "naver_blog")
    brand.brand_channels.create!(platform: "facebook_page")
    Member.create!(name: "등록 전 회원", email: "before@example.test", slug: "before")
    Member.create!(name: "다른 테넌트 회원", email: "elsewhere@example.test", slug: "elsewhere", tenant_id: 2)

    get pd_root_path

    assert_response :ok
    assert_select "h2", text: "회원 대행 등록"
    assert_select "a[href=?]", pd_members_path(filter: "todo"), text: "등록이 남은 회원 2명"
    assert_select "a[href=?]", pd_members_path(filter: "consent"), text: "위탁 동의 대기 1명"
    assert_select "a[href^='/admin']", count: 0
  end

  test "운영자 홈에는 최근 문의 전체 보기와 대행 등록이 없을 때의 안내가 표시된다" do
    sign_in AdminUser.create!(email: "admin-dashboard@example.test", password: "password123", role: "admin")

    get pd_root_path

    assert_response :ok
    assert_select "a[href=?]", admin_inquiries_path, text: "전체 보기"
    assert_select "p", text: "지금 남은 대행 등록이 없습니다."
    assert_select "a[href=?]", pd_members_path, text: "회원 대행 등록 열기"
  end

  test "로그인이 필요하다" do
    get pd_root_path
    assert_redirected_to new_admin_user_session_path
  end
end
