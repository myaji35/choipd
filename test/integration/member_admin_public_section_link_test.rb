require "test_helper"

class MemberAdminPublicSectionLinkTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(name: "테스트 회원", email: "public-section-link@example.com", slug: "public-section-link",
      status: "approved", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "보이는 서비스가 있으면 내 페이지 서비스 칸 링크를 보여 준다" do
    @member.member_services.create!(title: "상담", is_active: 1)

    get slug_admin_services_path(slug: @member.slug)

    assert_response :ok
    assert_select "p.impd-public-section-link a[href=?][target='_blank']", "/#{@member.slug}#classes",
      text: /내 페이지에서 '서비스' 칸 보기/
  end

  test "서비스가 모두 숨김이면 링크를 보여 주지 않는다" do
    @member.member_services.create!(title: "상담", is_active: 0)

    get slug_admin_services_path(slug: @member.slug)

    assert_response :ok
    assert_select "p.impd-public-section-link", count: 0
  end

  test "공개 소식이 4개 이상이면 최근 3개만 보인다고 알려 준다" do
    4.times do |index|
      @member.member_posts.create!(title: "소식 #{index}", content: "새 소식이에요.", is_published: 1)
    end

    get slug_admin_posts_path(slug: @member.slug)

    assert_response :ok
    assert_select "p.impd-label-muted", text: "내 페이지에는 가장 최근 소식 3개가 보여요."
    assert_select "p.impd-public-section-link a[href=?]", "/#{@member.slug}#posts"
  end

  test "카드 모음형은 칸 위치 없이 내 페이지로 보낸다" do
    @member.update!(layout_preset: "grid")
    @member.member_services.create!(title: "상담", is_active: 1)

    get slug_admin_services_path(slug: @member.slug)

    assert_response :ok
    assert_select "p.impd-public-section-link a[href=?]", "/#{@member.slug}"
  end
end
