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
    assert_includes response.body, "올린 파일은 바로 저장돼요"
    assert_select "ul.editor-file-rules li", count: 3
    assert_not_includes response.body, "포트폴리오"
    assert_not_includes response.body, "자동 분류"
    assert_not_includes response.body, "당신의 페이지"
  end

  test "정보 확인 단계에서 저장과 건너뛰기를 구분하고 쉬운 말을 쓴다" do
    get slug_admin_editor_path(slug: @member.slug, step: 2)

    assert_response :ok
    assert_select "a.impd-btn-primary", text: /다음/, count: 0
    assert_select "a.editor-skip-link[href='?step=3']", text: /저장하지 않고 다음 단계 보기/
    [ "역량", "포트폴리오", "자동 추출" ].each { |phrase| assert_not_includes response.body, phrase }
    assert_includes response.body, "작업 사진·사례"
    assert_select ".editor-pair", count: 2
  end

  test "문서 유무에 맞게 강점 안내를 보여 준다" do
    path = slug_admin_editor_path(slug: @member.slug, step: 2)
    get path

    assert_response :ok
    assert_select "a[href='?step=1&tab=docs#docs']", text: "← 문서 올리러 가기"
    assert_not_includes response.body, "문서 더 올리기"

    @member.member_documents.create!(tenant_id: 1, filename: "career.txt", category: "career", content_md: "경력 메모")
    get path

    assert_response :ok
    assert_includes response.body, "아직 강점을 찾지 못했어요"
    assert_select "a[href='?step=1&tab=docs#docs']", text: "문서 더 올리기"
    assert_not_includes response.body, "문서 올리러 가기"
    assert_select "label[for=member_phone]", text: "전화번호"
    assert_includes response.body, "min-height: 48px"
    assert_not_includes response.body, "카카오톡 채널 URL"
  end

  test "공개 단계의 준비 항목은 대시보드와 같다" do
    get slug_admin_dashboard_path(slug: @member.slug)
    assert_response :ok
    dashboard_count = css_select("summary").map(&:text).filter_map { |text| text[/전체 체크리스트 (\d+\/6)/, 1] }.first
    assert dashboard_count

    get slug_admin_editor_path(slug: @member.slug, step: 4)
    assert_response :ok
    assert_select "h2.impd-label", text: "내 페이지 준비 항목"
    assert_select "span.impd-display", text: dashboard_count
    MemberAdmin::ChecklistHelper::CHECKLIST_LABELS.values.each do |label|
      assert_select "li", text: /#{Regexp.escape(label)}/
    end
    assert_not_includes response.body, "강점 3개 이상"
    assert_not_includes response.body, "하러 가기"
    assert_no_match(/준비 \d+%/, response.body)
    assert_select ".editor-page a[href*='from=checklist']", count: 0
    %w[profile-photo bio profession-region media new-service docs].each do |anchor|
      assert_select ".editor-page li a[href$='##{anchor}']", count: 1
    end
  end

  test "기본 정보가 없으면 공개 버튼이 꺼져 있고 갈 곳을 알려 준다" do
    path = slug_admin_editor_path(slug: @member.slug, step: 4)
    get path

    assert_response :ok
    assert_select "button[type=submit][disabled]", count: 1
    assert_includes response.body, "자기소개(20자 이상)·직업·이메일을 적으면 공개할 수 있어요."
    assert_select "a[href$='step=2#bio']", text: "내 정보 적으러 가기 →"

    @member.update!(bio: "스마트폰으로 영상 만드는 법을 가르치는 강사입니다.", profession: "educator", email: @member.email)
    get path

    assert_response :ok
    assert_select "button[type=submit][disabled]", count: 0
    assert_select "button[type=submit]", text: "지금 공개하기"
  end

  test "올릴 수 없는 문서는 글 파일로 저장하는 방법을 안내한다" do
    post slug_admin_documents_path(slug: @member.slug, format: :json), params: { filename: "a.pdf", content: "x" }

    assert_response :unprocessable_entity
    assert_equal "INVALID_EXT", response.parsed_body.fetch("error")
    assert_equal "이 파일은 올릴 수 없어요. 글 파일(.txt)로 저장해서 올려 주세요.", response.parsed_body.fetch("message")
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
