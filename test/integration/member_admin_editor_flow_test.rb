require "test_helper"
require "uri"

class MemberAdminEditorFlowTest < ActionDispatch::IntegrationTest
  setup do
    slug = "editor-flow-#{SecureRandom.hex(4)}"
    @member = Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug,
      status: "approved", business_type: "individual", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "자료 올리기에는 다음 버튼이 있다" do
    get slug_admin_editor_path(slug: @member.slug, step: 1)

    assert_response :ok
    assert_select "a.impd-btn-primary[href='?step=2']", text: "다음 →"
  end

  test "정보 확인 단계에서 저장과 건너뛰기를 구분하고 쉬운 말을 쓴다" do
    get slug_admin_editor_path(slug: @member.slug, step: 2)

    assert_response :ok
    assert_select "a.impd-btn-primary", text: /다음/, count: 0
    assert_select "a.editor-skip-link[href='?step=3']", text: /저장하지 않고 다음 단계 보기/
    ["역량", "포트폴리오", "자동 추출"].each { |phrase| assert_not_includes response.body, phrase }
    assert_includes response.body, "작업 사진·사례"
    assert_select ".editor-pair", count: 2
  end

  test "스타일 선택 단계에서 건너뛰기와 저장 방법을 안내한다" do
    get slug_admin_editor_path(slug: @member.slug, step: 3)

    assert_response :ok
    assert_select "a.impd-btn-primary", text: /다음/, count: 0
    assert_select "a.editor-skip-link[href='?step=4']", text: /저장하지 않고 다음 단계 보기/
    assert_includes response.body, "골랐어요"
    assert_includes response.body, "카드를 누른 뒤 이 버튼을 눌러야 저장돼요."
    assert_not_includes response.body, "에디토리얼"
  end

  test "스타일을 고르지 않고 저장하면 선택 방법을 안내한다" do
    patch slug_admin_editor_update_style_path(slug: @member.slug)

    assert_response :redirect
    location = URI.parse(response.location)
    assert_equal slug_admin_editor_path(slug: @member.slug), location.path
    query = Rack::Utils.parse_query(location.query)
    assert_equal "3", query["step"]
    assert_equal "스타일 카드를 하나 누른 뒤 저장해 주세요.", query["alert"]
  end
end
