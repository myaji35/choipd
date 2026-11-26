require "test_helper"

class MemberReviewVisitorTest < ActionDispatch::IntegrationTest
  setup do
    token = SecureRandom.hex(5)
    @member = Member.create!(name: "테스트 회원", email: "#{token}@example.com", slug: "member-#{token}", status: "approved")
    @review_path = "/#{@member.slug}/review"
    @review_params = { rating: 5, reviewer_name: "김고객", content: "설명이 쉬웠어요." }
  end

  test "signed-out visitors see the review form without platform promotions" do
    get @review_path

    assert_response :ok
    assert_select ".impd-joinstrip, .impd-topnav-links, .impd-frap, #promo-popup-overlay", count: 0
    assert_not_includes response.body, "REVIEW"
    assert_select "p", text: "이름은 후기와 함께 공개돼요."
    assert_select "p", text: "이메일은 공개되지 않아요."
  end

  test "review form has a single main landmark and heading" do
    get @review_path

    assert_select "main", 1
    assert_select "main h1", 1
  end

  test "validation explains missing fields in Korean and preserves the draft" do
    post @review_path, params: { member_review: { content: @review_params[:content] } }

    assert_response :unprocessable_entity
    assert_select "#review-alert[role=alert]" do
      assert_select "p", text: "별점을 골라 주세요."
      assert_select "p", text: "이름을 적어 주세요."
    end
    assert_not_includes response.body, "is not included"
    assert_not_includes response.body, "can't be blank"
    assert_select "textarea#member_review_content", text: @review_params[:content]
  end

  test "a submitted review waits for approval and shows a confirmation instead of the form" do
    assert_difference -> { @member.member_reviews.where(status: "new").count }, 1 do
      post @review_path, params: { member_review: @review_params }
    end

    assert_review_confirmation

    get @review_path
    assert_select "#review-sent", count: 0
    assert_select "form[action=?] textarea", @review_path, count: 1
  end

  test "the honeypot shows the same confirmation without saving a review" do
    assert_no_difference "MemberReview.count" do
      post @review_path, params: { website: "https://example.com", member_review: @review_params }
    end

    assert_review_confirmation
  end

  test "signed-in members retain the platform navigation in preview" do
    @member.update!(password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    get @review_path

    assert_response :ok
    assert_select ".impd-topnav-links", count: 1
  end

  private

  def assert_review_confirmation
    assert_response :see_other
    follow_redirect!
    assert_select "#review-sent[role=status] p", text: "후기를 보냈어요. 고맙습니다."
    assert_select "form[action=?]", @review_path, count: 0
    assert_select "#review-sent a[href=?]", "/#{@member.slug}", count: 1
  end
end
