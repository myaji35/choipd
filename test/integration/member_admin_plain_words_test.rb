require "test_helper"
require "uri"

class MemberAdminPlainWordsTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_member
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "목록 관리 화면에 영어 머리말과 기호가 없다" do
    slug = @member.slug
    {
      slug_admin_services_path(slug: slug) => "새 서비스 추가",
      slug_admin_faqs_path(slug: slug) => "새 질문 추가",
      slug_admin_bookings_path(slug: slug) => "새 예약 링크 추가",
      slug_admin_reviews_path(slug: slug) => "후기 받기"
    }.each do |path, heading|
      get path
      assert_response :ok
      %w[§01 §02 SERVICES BOOKINGS REVIEWS].each do |word|
        assert_no_match word, response.body
      end
      ["신규 등록", "구조화 데이터", "외부 예약 URL"].each do |phrase|
        assert_no_match phrase, response.body
      end
      assert_includes response.body, heading
      assert_select "#new-service.checklist-target", count: 1 if heading == "새 서비스 추가"
    end
  end

  test "서비스 상태를 회원 말로 보여 준다" do
    @member.member_services.create!(title: "상담", is_active: 1)
    @member.member_services.create!(title: "강의", is_active: 0)

    get slug_admin_services_path(slug: @member.slug)
    assert_response :ok
    assert_includes response.body, "보이는 중"
    assert_includes response.body, "숨김"
    assert_no_match "비활성", response.body
  end

  test "에디터 3·4단계에 발행·프리셋 같은 말이 없다" do
    get slug_admin_editor_path(slug: @member.slug, step: 3)
    assert_response :ok
    %w[프리셋 발행 EDITORIAL 미설정 레이아웃].each do |word|
      assert_no_match word, response.body
    end
    assert_select "h1", count: 1
    assert_includes response.body, "이 스타일로 저장하고 다음"

    get slug_admin_editor_path(slug: @member.slug, step: 4)
    assert_response :ok
    ["발행", "OG 메타", "달란트", "활성화"].each do |word|
      assert_no_match word, response.body
    end
    assert_select "h1", count: 1, text: "내 페이지 공개하기"
    assert_includes response.body, "지금 공개하기"
  end

  test "스타일을 저장하면 4단계로 가고 공개되지는 않는다" do
    patch slug_admin_editor_update_style_path(slug: @member.slug), params: { theme_preset: "clean" }

    assert_response :redirect
    assert_equal "4", Rack::Utils.parse_query(URI.parse(response.location).query).fetch("step")
    assert_equal "clean", @member.reload.theme_preset
    assert_nil @member.published_at
  end

  test "문서 줄의 지우기 버튼은 화면 공통 버튼 모양이다" do
    @member.member_documents.create!(filename: "경력.txt", category: "career", content_md: "경력 소개")

    get slug_admin_editor_path(slug: @member.slug, step: 1)
    assert_response :ok
    assert_select 'button.impd-btn[data-action="click->member-doc-row#destroy"]', count: 1, text: "지우기"
    assert_no_match "빼기", response.body
    assert_no_match "분류 바꾸기", response.body
  end

  test "에디터 뷰에 고정폭 글꼴이 없다" do
    Dir[Rails.root.join("app/views/member_admin/editor/*.erb")].each do |path|
      assert_no_match "impd-font-mono", File.read(path), path
    end
  end

  private

  def create_member
    slug = "plain-words-#{SecureRandom.hex(4)}"
    Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug, status: "approved",
      business_type: "individual", password: "password1234", password_confirmation: "password1234")
  end
end
