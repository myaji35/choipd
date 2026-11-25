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
    assert_select "article span", text: "확인할 후기", count: 0
    assert_select "article button.impd-btn-quiet", text: "공개 안 하고 숨기기"
    assert_select "article button.impd-btn-secondary", count: 0
    assert_not_includes response.body, "승인 대기"
    assert_select ".review-stars [aria-hidden]", text: "★★★★★"
    assert_select ".review-stars-num", text: "5점"
    assert_includes response.body, "별점만 남긴 후기예요."
  end

  test "후기 받는 주소 복사를 주 버튼으로 표시한다" do
    get slug_admin_reviews_path(slug: @member.slug)

    assert_response :ok
    assert_select "#review-request" do
      assert_select "button.impd-btn-primary[type=button]", text: "주소 복사", count: 1
      assert_select "a.impd-btn-secondary", text: "고객이 보는 화면 미리 보기"
      assert_select "a.impd-btn-primary", count: 0
      assert_select 'input[aria-label="후기 받는 주소"][readonly]'
    end
    assert_includes response.body, "카카오톡이나 문자에 붙여 넣어 보내면 돼요."
  end

  test "공개된 후기에서는 글자 버튼으로 내 페이지에서 숨길 수 있다" do
    @member.member_reviews.create!(reviewer_name: "고객", rating: 5, status: "triaged")

    get slug_admin_reviews_path(slug: @member.slug)

    assert_response :ok
    assert_select "article button.impd-btn-quiet", text: "내 페이지에서 숨기기"
  end

  test "후기가 없으면 확인할 후기 배지를 표시하지 않는다" do
    get slug_admin_reviews_path(slug: @member.slug)

    assert_response :ok
    assert_select "header span", text: /확인할 후기/, count: 0
  end

  test "별점과 받은 시각을 표시한다" do
    @member.member_reviews.create!(reviewer_name: "고객", rating: 3, created_at: Time.utc(2026, 11, 9, 18))

    get slug_admin_reviews_path(slug: @member.slug)

    assert_select "article" do
      assert_select ".review-stars[aria-label=?] [aria-hidden]", "별점 5점 만점에 3점", text: "★★★☆☆"
      assert_select ".review-stars-num", text: "3점"
      assert_select "i.lni-star-fat", count: 0
      assert_select "time", text: "2026.11.10 03:00"
    end
  end

  test "숨긴 후기에서 다시 공개할 수 있다" do
    @member.member_reviews.create!(reviewer_name: "고객", rating: 3, status: "archived")

    get slug_admin_reviews_path(slug: @member.slug)

    assert_select "h2", text: "숨긴 후기"
    assert_select "article button.impd-btn-secondary", text: "다시 공개하기"
    assert_not_includes response.body, "보관"
  end

  test "공개하거나 숨긴 후기의 알림을 표시한다" do
    review = @member.member_reviews.create!(reviewer_name: "고객", rating: 3, status: "new")

    post approve_slug_admin_review_path(slug: @member.slug, id: review)
    follow_redirect!
    assert_includes response.body, "후기를 내 페이지에 공개했어요."

    post reject_slug_admin_review_path(slug: @member.slug, id: review)
    follow_redirect!
    assert_includes response.body, "후기를 숨겼어요."
    assert_select "article#review-#{review.id}.is-just-saved"
  end
end
