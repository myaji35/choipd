require "test_helper"

class MemberAdminButtonToneTest < ActionDispatch::IntegrationTest
  setup do
    @slug = "button-tone-#{SecureRandom.hex(4)}"
    @member = Member.create!(name: "테스트 회원", email: "#{@slug}@example.com", slug: @slug,
      status: "approved", business_type: "individual", password: "password1234", password_confirmation: "password1234",
      published_at: Time.current)
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "주 버튼과 삭제 버튼 색은 회원 관리에만 적용한다" do
    get slug_admin_services_path(slug: @slug)

    assert_response :ok
    assert_includes response.body, ".impd-admin .impd-btn-primary"
    assert_includes response.body, "#b42318"

    get "/#{@slug}"

    assert_response :ok
    assert_not_includes response.body, ".impd-admin .impd-btn-primary"
  end
end
