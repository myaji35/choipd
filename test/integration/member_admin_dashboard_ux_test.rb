require "test_helper"

class MemberAdminDashboardUxTest < ActionDispatch::IntegrationTest
  test "dashboard shows the next task and grouped navigation" do
    member = Member.create!(name: "테스트 회원", email: "dashboard-#{SecureRandom.hex(4)}@example.com", slug: "dashboard-#{SecureRandom.hex(4)}", status: "approved", business_type: "individual", profession: "custom", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: member.email, password: "password1234" }
    get slug_admin_dashboard_path(slug: member.slug)
    assert_response :success
    assert_includes response.body, "다음 할 일"
    assert_includes response.body, "전체 체크리스트"
    %w[내\ 페이지 고객 홍보].each { |heading| assert_includes response.body, heading }
    assert_not_includes response.body, "예시 페이지"
    assert_includes response.body, "아직 방문이 적어요"
  end
end
