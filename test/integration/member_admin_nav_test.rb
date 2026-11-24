require "test_helper"

class MemberAdminNavTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(
      name: "테스트 회원", email: "nav-#{SecureRandom.hex(4)}@example.com",
      slug: "nav-#{SecureRandom.hex(4)}", status: "approved",
      business_type: "individual", profession: "custom",
      password: "password1234", password_confirmation: "password1234"
    )
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "services highlights the page group and services link" do
    assert_current_navigation "services", "내 페이지", "서비스"
  end

  test "reviews highlights the customer group and reviews link" do
    assert_current_navigation "reviews", "고객", "후기"
  end

  test "scheduled posts highlights the promotion group and scheduled posts link" do
    assert_current_navigation "scheduled_posts", "홍보", "예약 발행"
  end

  test "dashboard highlights its primary link and hides secondary navigation" do
    get slug_admin_dashboard_path(slug: @member.slug)
    assert_response :success
    assert_select '.admin-nav-links a[aria-current="page"]', text: "대시보드", count: 1
    assert_select ".admin-subnav", count: 0
  end

  private

  def assert_current_navigation(screen, group_label, screen_label)
    get "/#{@member.slug}/admin/#{screen}"
    assert_response :success
    assert_select '.admin-nav-links a[aria-current="page"]', text: group_label, count: 1
    assert_select '.admin-subnav a[aria-current="page"]', text: screen_label, count: 1
    assert_select '.admin-mobile-panel a[aria-current="page"]', text: screen_label, count: 1
  end
end
