require "test_helper"

class MemberAdmin::EditorControllerTest < ActionDispatch::IntegrationTest
  test "signed in member sees the current editor step" do
    member = Member.create!(tenant_id: 1, name: "편집 회원", email: "editor-#{SecureRandom.hex(4)}@example.com",
                            slug: "editor-#{SecureRandom.hex(4)}", business_type: "individual", profession: "custom",
                            status: "approved", impd_status: "none", password: "password1234",
                            password_confirmation: "password1234")
    post "/auth/login", params: { email: member.email, password: "password1234" }
    get slug_admin_editor_path(slug: member.slug)
    assert_response :success
    assert_select "h1", count: 1
    assert_select '[aria-current="step"]', count: 1
    assert_no_match "MD · TXT", response.body
    get slug_admin_editor_path(slug: member.slug, step: 3)
    assert_response :success
    assert_select "h1", count: 1
    assert_select '[aria-current="step"]', count: 1
  end
end
