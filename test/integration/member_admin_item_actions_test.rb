require "test_helper"

class MemberAdminItemActionsTest < ActionDispatch::IntegrationTest
  setup do
    @slug = "item-actions-#{SecureRandom.hex(4)}"
    @member = Member.create!(name: "테스트 회원", email: "#{@slug}@example.com", slug: @slug,
      status: "approved", business_type: "individual", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "서비스 카드에서 수정, 표시 전환, 삭제를 할 수 있다" do
    service = @member.member_services.create!(title: "상담", price: "50000", is_active: 1)

    get slug_admin_services_path(slug: @slug)
    assert_select "article#service-#{service.id} .impd-item-actions" do
      assert_select "summary", text: "수정"
      assert_select "button", text: "내 페이지에서 숨기기"
      assert_select ".impd-item-delete button.impd-btn-danger", text: "삭제"
    end

    patch slug_admin_service_path(slug: @slug, id: service),
      params: { member_service: { is_active: 0 }, visibility_toggle: 1 }
    assert_response :redirect
    assert_equal 0, service.reload.is_active.to_i
    assert_equal "상담", service.title
    assert_equal "50000", service.price
    follow_redirect!
    assert_includes response.body, "서비스를 내 페이지에서 숨겼어요."
    assert_select "article#service-#{service.id}.is-just-saved" do
      assert_select "span", text: "숨김"
      assert_select "button", text: "내 페이지에 보이기"
    end
  end

  test "질문 카드에서 수정, 표시 전환, 삭제를 할 수 있다" do
    faq = @member.member_faqs.create!(question: "어디에서 만나나요?", answer: "온라인으로 만나요.", is_published: 1)

    get slug_admin_faqs_path(slug: @slug)
    assert_select ".admin-subnav a", text: "자주 묻는 질문"
    assert_select ".admin-subnav a", text: "FAQ", count: 0
    assert_select "article#faq-#{faq.id} .impd-item-actions" do
      assert_select "summary", text: "수정"
      assert_select "button", text: "내 페이지에서 숨기기"
      assert_select ".impd-item-delete button.impd-btn-danger", text: "삭제"
    end

    patch slug_admin_faq_path(slug: @slug, id: faq),
      params: { member_faq: { is_published: 0 }, visibility_toggle: 1 }
    assert_response :redirect
    assert_equal 0, faq.reload.is_published.to_i
    assert_equal "어디에서 만나나요?", faq.question
    assert_equal "온라인으로 만나요.", faq.answer
    follow_redirect!
    assert_includes response.body, "질문을 내 페이지에서 숨겼어요."
    assert_select "article#faq-#{faq.id}.is-just-saved" do
      assert_select "span", text: "숨김"
      assert_select "button", text: "내 페이지에 보이기"
    end
  end

  test "예약 링크 카드에는 수정과 삭제가 있다" do
    booking = @member.member_bookings.create!(external_url: "https://example.com/booking")

    get slug_admin_bookings_path(slug: @slug)

    assert_select "article#booking-#{booking.id} .impd-item-actions" do
      assert_select "summary", text: "수정"
      assert_select ".impd-item-delete button.impd-btn-danger", text: "삭제"
      assert_select "button", text: /숨기기/, count: 0
    end
  end

  test "서비스를 추가하면 저장한 카드만 한 번 강조한다" do
    @member.member_services.create!(title: "기존 서비스")

    post slug_admin_services_path(slug: @slug), params: { member_service: { title: "새 상담" } }
    follow_redirect!
    assert_select "article.is-just-saved", count: 1 do
      assert_select "h3", text: "새 상담"
      assert_select ".impd-just-saved-tag", text: "방금 저장"
    end

    get slug_admin_services_path(slug: @slug)
    assert_select "article.is-just-saved", count: 0
  end

  test "수정한 소식 카드를 강조한다" do
    news = @member.member_posts.create!(title: "소식", content: "기존 내용")

    patch slug_admin_post_path(slug: @slug, id: news), params: { member_post: { content: "새 내용" } }
    follow_redirect!
    assert_select "article#post-#{news.id}.is-just-saved"
  end

  test "공개한 후기 카드를 강조한다" do
    review = @member.member_reviews.create!(reviewer_name: "고객", rating: 5, status: "new")

    post approve_slug_admin_review_path(slug: @slug, id: review)
    follow_redirect!
    assert_select "article#review-#{review.id}.is-just-saved"
  end
end
