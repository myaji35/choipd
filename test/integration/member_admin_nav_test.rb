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

  test "legacy SNS screens highlight the promotion group without a current submenu link" do
    %w[sns_accounts scheduled_posts].each do |screen|
      get "/#{@member.slug}/admin/#{screen}"

      assert_response :success
      assert_select '.admin-nav-links a[aria-current="page"]', text: "홍보", count: 1
      assert_select '.admin-subnav[aria-label="홍보 메뉴"] a', count: 2
      assert_select '.admin-subnav a[aria-current="page"]', count: 0
      assert_select '.admin-mobile-panel a[aria-current="page"]', count: 0
    end
  end

  test "dashboard highlights its primary link and hides secondary navigation" do
    get slug_admin_dashboard_path(slug: @member.slug)
    assert_response :success
    assert_select '.admin-nav-links a[aria-current="page"]', text: "대시보드", count: 1
    assert_select ".admin-subnav", count: 0
  end

  test "회원 메뉴에서는 페이지 만들기라고 부른다" do
    slug = @member.slug
    [ slug_admin_editor_path(slug: slug), slug_admin_dashboard_path(slug: slug), slug_admin_services_path(slug: slug) ].each do |path|
      get path

      assert_response :ok
      assert_select "a", text: "페이지 만들기", minimum: 1
      assert_not_includes response.body, "에디터"
    end
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
