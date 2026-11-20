require "test_helper"

class BrandOpsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @old_members_threshold = ENV["BRAND_OPS_MEMBERS_THRESHOLD"]
    @old_active_min = ENV["BRAND_OPS_ACTIVE_MIN"]
    @old_communication_min = ENV["BRAND_OPS_COMMUNICATION_MIN"]
    ENV["BRAND_OPS_ACTIVE_MIN"] = "0"
    ENV["BRAND_OPS_COMMUNICATION_MIN"] = "0"
    @member = Member.create!(name: "운영 회원", email: "ops-page@example.com", slug: "ops-page", status: "approved", password: "password1234", password_confirmation: "password1234")
  end
  teardown do
    ENV["BRAND_OPS_MEMBERS_THRESHOLD"] = @old_members_threshold
    ENV["BRAND_OPS_ACTIVE_MIN"] = @old_active_min
    ENV["BRAND_OPS_COMMUNICATION_MIN"] = @old_communication_min
  end

  test "growth shows accessible charts and signup" do
    get "/growth"
    assert_response :success
    assert_select "main", count: 1
    assert_select "details summary", text: "숫자는 이렇게 셌어요"
    assert_select "svg[role=img]"
    assert_select "table"
    assert_select ".ops-y-ticks span", minimum: 3
    assert_select ".ops-y-ticks span" do |ticks|
      ticks.each { |tick| assert_no_match(/\./, tick.text) }
    end
    assert_select ".ops-hero > .ops-key-grid", count: 1
    assert_match(/@media\(max-width:640px\).*\.ops-hero \.ops-key-grid\{[^}]*order:1\}\.ops-hero \.ops-featured\{order:2\}/, Rails.root.join("app/assets/stylesheets/brand_ops.css").read)
    assert_select "svg .ops-area"
    assert_select ".ops-communication-grid section.ops-surface-card", count: 5
    assert_select ".ops-activity-chart-mobile:not([open]) > summary", text: "문의와 활동 그래프 보기"
    assert_select ".ops-closing h2", text: "다음 운영 사례의 주인공이 되어 보세요"
    assert_select ".ops-closing a[href=?]", member_signup_path, text: "내 페이지 만들기"
    assert_select ".ops-closing a[href=?]", "/explore", text: "먼저 둘러보기"
    assert_select ".ops-hero p", text: /회원 [\d,]+명이 페이지를 운영하고 있고, 이번 주에만 방문 [\d,]+회가 오갔어요\./
    assert_select ".ops-brand-card", 0..6
    assert_select "a", text: "내 페이지 만들기"
    assert_select ".ops-hero .ops-key-grid section", count: 4
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

  test "growth brand cards have compact mobile layout" do
    ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true)
    get "/growth"
    assert_select ".ops-brand-card.ops-brand-card-compact .ops-brand-heading"
  end

  test "brand page requires consent and hides inquiry details" do
    get "/ops-page/brand"
    assert_response :not_found
    ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true)
    MemberInquiry.create!(member: @member, sender_name: "방문자", sender_email: "private@example.com", message: "비밀 문의 내용")
    get "/ops-page/brand"
    assert_response :success
    assert_select "main", count: 1
    assert_select "details summary", text: "숫자는 이렇게 셌어요"
    assert_select "header a.ops-growth-chip[href=?]", "/growth", text: /imPD 전체 운영 현황 보기/
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
      assert_equal "3#{unit} 미만", BrandOps::Display.count_with_unit(1, unit)
      assert_equal "3#{unit} 미만", BrandOps::Display.count_with_unit(2, unit)
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
    assert_includes response.body, "공개 중 (회원 50명 전까지는 항상 공개 — 지금 #{BrandOps::PublicGate.status[:members_total]}명)"
  end
  test "closed gate protects pages and shows owner status" do
    ENV["BRAND_OPS_MEMBERS_THRESHOLD"] = "0"
    ENV["BRAND_OPS_ACTIVE_MIN"] = "9999"
    ENV["BRAND_OPS_COMMUNICATION_MIN"] = "9999"
    ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true)
    get "/growth"
    assert_response :not_found
    get "/ops-page/brand"
    assert_response :not_found
    get "/"
    assert_select 'a[href="/growth"]', count: 0
    get "/explore"
    assert_select 'a[href="/growth"]', count: 0
    get "/ops-page"
    assert_select 'a[href="/ops-page/brand"]', count: 0
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    get "/ops-page/brand"
    assert_redirected_to "/ops-page/admin/brand"
    get "/ops-page/admin/brand"
    assert_includes response.body, "공개 상태: 아직 비공개"
    assert_includes response.body, "회원 0명 이상이라 기준을 적용 중"
    assert_select "a", text: /공개 페이지 보기/, count: 0
  end

  test "admin previews closed pages" do
    ENV["BRAND_OPS_MEMBERS_THRESHOLD"] = "0"
    ENV["BRAND_OPS_ACTIVE_MIN"] = "9999"
    ENV["BRAND_OPS_COMMUNICATION_MIN"] = "9999"
    ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true)
    admin = AdminUser.create!(email: "gate-admin@example.com", password: "password1234", role: "admin")
    sign_in admin
    get "/growth"
    assert_response :success
    assert_includes response.body, "공개 전 미리보기"
    assert_includes response.body, "회원 0명 이상이라 기준을 적용 중"
    get "/ops-page/brand"
    assert_response :success
    assert_includes response.body, "공개 전 미리보기"
    assert_select 'a[href="/growth"]', count: 0
  end

  test "open gate omits preview banner" do
    ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true)
    [ "/growth", "/ops-page/brand" ].each do |path|
      get path
      assert_response :success
      assert_not_includes response.body, "공개 전 미리보기"
    end
  end
end
