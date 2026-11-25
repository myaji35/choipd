require "test_helper"

class MemberAdmin::EditorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(tenant_id: 1, name: "편집 회원", email: "editor-#{SecureRandom.hex(4)}@example.com",
                            slug: "editor-#{SecureRandom.hex(4)}", business_type: "individual", profession: "custom",
                            status: "approved", impd_status: "none", password: "password1234",
                            password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "signed in member sees the current editor step" do
    get slug_admin_editor_path(slug: @member.slug)
    assert_response :success
    assert_select "h1", count: 1
    assert_select '[aria-current="step"]', count: 1
    assert_no_match "MD · TXT", response.body
    get slug_admin_editor_path(slug: @member.slug, step: 3)
    assert_response :success
    assert_select "h1", count: 1
    assert_select '[aria-current="step"]', count: 1
  end

  test "custom profession is saved in the existing field and shown on return" do
    update_path = slug_admin_editor_update_info_path(slug: @member.slug)
    editor_path = slug_admin_editor_path(slug: @member.slug, step: 2)

    patch update_path, params: { member: { profession: "custom", custom_profession: "  스마트폰 강사  " } }
    assert_response :redirect
    assert_equal "3", Rack::Utils.parse_query(URI.parse(response.location).query).fetch("step")
    assert_equal "스마트폰 강사", @member.reload.profession

    get editor_path
    assert_response :success
    assert_select 'select[name="member[profession]"] option[value="custom"][selected]'
    assert_select 'input[name="member[custom_profession]"][value="스마트폰 강사"]'

    patch update_path, params: { member: { profession: "educator", custom_profession: "스마트폰 강사" } }
    assert_equal "educator", @member.reload.profession
  end
end
