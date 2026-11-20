require "test_helper"

class BrandOpsTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(name: "운영 회원", email: "ops-page@example.com", slug: "ops-page", status: "approved", password: "password1234", password_confirmation: "password1234")
  end
  test "growth shows accessible charts and signup" do
    get "/growth"
    assert_response :success
    assert_select "svg[role=img]"
    assert_select "table"
    assert_select ".ops-y-ticks span", minimum: 3
    assert_select "svg .ops-area"
    assert_select ".ops-activity-grid section", count: 5
    assert_select ".ops-brand-card", 0..6
    assert_select "a", text: "내 페이지 만들기"
  end
  test "brand page requires consent and hides inquiry details" do
    get "/ops-page/brand"
    assert_response :not_found
    ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true)
    MemberInquiry.create!(member: @member, sender_name: "방문자", sender_email: "private@example.com", message: "비밀 문의 내용")
    get "/ops-page/brand"
    assert_response :success
    assert_select "h1", text: "운영 회원"
    assert_select ".ops-activity-grid section", count: 4
    assert_select "svg[aria-label=?]", "주간 추이: 방문, 게시+SNS 발행"
    assert_select "svg[aria-label*=문의]", 0
    assert_select "table th", text: "문의 건수", count: 0
    assert_select "table th", text: "게시+SNS 발행", count: 1
    assert_select ".ops-media-chip", text: /SocialDoctors/
    assert_select "a[href=?]", "/ops-page", text: "프로필 보기"
    assert_select ".impd-frap", count: 0
    assert_not_includes response.body, "비밀 문의 내용"
    assert_not_includes response.body, "private@example.com"
  end
  test "owner sees brand activity" do
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    get "/ops-page/admin/brand"
    assert_response :success
    assert_includes response.body, "내 브랜드 운영 현황"
  end
end
