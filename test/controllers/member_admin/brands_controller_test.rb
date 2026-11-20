require "test_helper"

class MemberAdmin::BrandsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(name: "브랜드 회원", email: "brand-#{SecureRandom.hex(4)}@example.com", slug: "kang-seung-sig", status: "approved", business_type: "individual", profession: "custom", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "shows an empty state without brands" do
    get slug_admin_brand_path(slug: @member.slug)
    assert_response :success
    assert_includes response.body, "/kang-seung-sig/brand"
    assert_not_includes response.body, "/slug/brand"
    assert_includes response.body, "아직 등록된 브랜드가 없어요"
    assert_includes response.body, "브랜드는 운영팀이 등록을 도와드려요"
    assert_select "a.impd-btn-secondary", text: "공개하려면 노출 동의하기"
  end

  test "shows only the member's brands" do
    Brand.create!(name: "내 브랜드", member_id: @member.id, business_type: "보험", region: "성남")
    Brand.create!(name: "다른 브랜드")
    get slug_admin_brand_path(slug: @member.slug)
    assert_response :success
    assert_includes response.body, "내 브랜드"
    assert_includes response.body, "성남"
    assert_not_includes response.body, "다른 브랜드"
    assert_not_includes response.body, "브랜드는 운영팀이 등록을 도와드려요"
  end
  test "shows raw four week counts and changes" do
    4.times { AnalyticsEvent.create!(event_name: "page_view", event_category: "page", page_path: "/#{@member.slug}") }
    MemberInquiry.create!(member: @member, sender_name: "방문자", sender_email: "visitor@example.com", message: "문의 내용입니다")
    2.times { MemberPost.create!(member: @member, title: "이전 게시", content: "내용", is_published: 1, published_at: 5.weeks.ago) }
    scheduled = SnsScheduledPost.create!(member: @member, message: "내용", platform: "instagram", scheduled_at: Time.current)
    2.times { SnsPostHistory.create!(sns_scheduled_post: scheduled, status: "success") }
    get slug_admin_brand_path(slug: @member.slug)
    assert_select ".ops-owner-stats section", count: 4
    assert_select ".ops-owner-stats section", text: /방문.*4회.*4회 늘었어요/m
    assert_select ".ops-owner-stats section", text: /문의.*1건.*1건 늘었어요/m
    assert_select ".ops-owner-stats section", text: /게시.*0건.*2건 줄었어요/m
    assert_select ".ops-owner-stats section", text: /SNS 발행.*2건.*2건 늘었어요/m
    assert_includes response.body, "이번 달 imPD 게시 0건 · SNS 발행 2건"
  end
end
