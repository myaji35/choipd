require "test_helper"

class PublicPagesTest < ActionDispatch::IntegrationTest
  test "homepage returns 200" do
    get root_path
    assert_response :success
    assert_select "footer a[href=?]", new_inquiry_path, text: "문의하기"
    assert_select "a[href=?]", privacy_path, text: "개인정보처리방침", count: 1
  end

  test "homepage CTAs reflect member session" do
    get root_path
    assert_select ".impd-hero-actions a.impd-btn-primary", text: /내 페이지 만들기/

    member = Member.create!(name: "회원", email: "home-#{SecureRandom.hex(4)}@example.com",
      slug: "home-#{SecureRandom.hex(4)}", status: "approved", password: "password1234")
    post login_member_post_path(slug: member.slug), params: { password: "password1234" }
    get root_path

    assert_response :success
    assert_select ".impd-hero-actions a.impd-btn-primary[href=?]", "/#{member.slug}/admin/dashboard", text: /내 페이지 관리/ do
      assert_select "i.lni-pencil-1"
    end
    assert_select ".impd-hero-actions", text: /내 페이지 만들기/, count: 0
    assert_select ".impd-hero-actions a[href=?]", "/#{member.slug}", text: /내 페이지 보기/
    assert_operator css_select("a[href='/#{member.slug}/admin/dashboard']").count { |link| link.text.include?("내 페이지 관리") }, :>=, 3
    assert_operator css_select("a[href='/#{member.slug}']").count { |link| link.text.include?("내 페이지 보기") }, :>=, 2
  end

  test "inquiry page returns 200" do
    get new_inquiry_path
    assert_response :success
  end

  test "education page returns 200" do
    get education_path
    assert_response :success
  end

  test "media page returns 200" do
    get media_path
    assert_response :success
  end

  test "works page returns 200" do
    get works_path
    assert_response :success
  end

  test "community page returns 200" do
    get community_path
    assert_response :success
  end
end
