require "test_helper"

class MemberAdminReviewsUxTest < ActionDispatch::IntegrationTest
  setup do
    slug = "reviews-ux-#{SecureRandom.hex(4)}"
    @member = Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug,
      status: "approved", business_type: "individual", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "후기 화면에 경로와 제목, 공개 방법을 표시한다" do
    get slug_admin_reviews_path(slug: @member.slug)

    assert_response :ok
    assert_select "p.impd-label-muted", text: "고객 › 후기"
    assert_select "h1.impd-display", text: "후기"
    assert_includes response.body, "고객이 남긴 후기를 읽어 보고, 내 페이지에 보여 줄 것만 '공개하기'를 눌러 주세요."
    assert_select "main main", count: 0
  end

  test "새 후기는 확인할 후기로 표시한다" do
    @member.member_reviews.create!(reviewer_name: "고객", rating: 5, status: "new")

    get slug_admin_reviews_path(slug: @member.slug)

    assert_response :ok
    assert_select "header span", text: "확인할 후기 1건"
    assert_select "h2", text: "확인할 후기"
    assert_not_includes response.body, "승인 대기"
    assert_includes response.body, "별점만 남긴 후기예요."
  end

  test "후기가 없으면 확인할 후기 배지를 표시하지 않는다" do
    get slug_admin_reviews_path(slug: @member.slug)

    assert_response :ok
    assert_select "header span", text: /확인할 후기/, count: 0
  end
end
