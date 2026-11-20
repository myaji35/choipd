require "test_helper"

class BrandOpsTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(name: "운영 회원", email: "ops-page@example.com", slug: "ops-page", status: "approved", password: "password1234", password_confirmation: "password1234")
  end
  test "growth shows accessible charts and signup" do
    get "/growth"
    assert_response :success
    assert_select "main", count: 1
    assert_select "svg[role=img]"
    assert_select "table"
    assert_select ".ops-y-ticks span", minimum: 3
    assert_select "svg .ops-area"
    assert_select ".ops-activity-grid section", count: 5
    assert_select ".ops-brand-card", 0..6
    assert_select "a", text: "내 페이지 만들기"
    assert_select ".ops-key-grid section", count: 4
    assert_not_includes response.body, "미만건"
  end
  test "period selection marks the active link" do
    get "/growth"
    assert_select ".ops-period a[aria-current=true]", text: "12주"
    get "/growth", params: { weeks: 26 }
    assert_select ".ops-period a[aria-current=true]", text: "26주"
    assert_select ".ops-period a[aria-current]", count: 1
  end

  test "featured case uses the first consented member" do
    @member.update!(slug: "kang-seung-sig")
    get "/growth"
    assert_select ".ops-featured", count: 0
    ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true)
    get "/growth"
    assert_select ".ops-featured a[href=?]", "/kang-seung-sig/brand", text: /이 브랜드가 운영되는 모습 보기/
  end

  test "brand page requires consent and hides inquiry details" do
    get "/ops-page/brand"
    assert_response :not_found
    ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true)
    MemberInquiry.create!(member: @member, sender_name: "방문자", sender_email: "private@example.com", message: "비밀 문의 내용")
    get "/ops-page/brand"
    assert_response :success
    assert_select "main", count: 1
    assert_select "h1", text: "운영 회원"
    assert_match(/imPD에서 1개월째 운영 중 · 최근 4주 방문 0회 · 게시 0건/, response.body)
    assert_select "a.impd-btn-primary", text: "나도 이렇게 운영하기"
    assert_select ".ops-activity-grid section", count: 4
    assert_select "svg[aria-label=?]", "주간 추이: 방문, 게시+SNS 발행"
    assert_select "svg[aria-label*=문의]", 0
    assert_select "table th", text: "문의 건수", count: 0
    assert_select "table th", text: "게시+SNS 발행", count: 1
    assert_select ".ops-media-chip", text: /SocialDoctors/
    assert_select "a[href=?]", "/ops-page", text: "프로필 보기"
    assert_select ".impd-frap", count: 0
    assert_not_includes response.body, "미만건"
    assert_not_includes response.body, "비밀 문의 내용"
    assert_not_includes response.body, "private@example.com"
  end
  test "count with unit protects small counts" do
    %w[건 회].each do |unit|
      assert_equal "0#{unit}", BrandOps::Display.count_with_unit(0, unit)
      assert_equal "3건 미만", BrandOps::Display.count_with_unit(1, unit)
      assert_equal "3건 미만", BrandOps::Display.count_with_unit(2, unit)
      assert_equal "12#{unit}", BrandOps::Display.count_with_unit(12, unit)
    end
  end

  test "chart fallback is visually hidden" do
    css = Rails.root.join("app/assets/stylesheets/brand_ops.css").read
    assert_match(/\.ops-sr-only\s*\{[^}]*position\s*:\s*absolute/, css)
  end

  test "owner sees management link on public brand page" do
    ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true)
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    get "/ops-page/brand"
    assert_select "a", text: "내 브랜드 관리로 가기"
    assert_select "a", text: "나도 이렇게 운영하기", count: 0
    assert_select "a", text: "이 분께 문의하기", count: 0
  end

  test "owner sees brand activity" do
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    get "/ops-page/admin/brand"
    assert_response :success
    assert_includes response.body, "내 브랜드 운영 현황"
  end
end
