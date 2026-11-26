require "test_helper"

class ExampleProfileLinkTest < ActionDispatch::IntegrationTest
  setup do
    Member.update_all(status: "pending_approval")
  end

  test "example links use an existing public profile when choi-pd is absent" do
    assert_not Member.exists?(slug: "choi-pd")
    member = Member.create!(name: "예시 회원", email: "example-#{SecureRandom.hex(4)}@example.com",
      slug: "example-#{SecureRandom.hex(4)}", status: "approved", password: "password1234", is_featured: true)
    profile_path = "/#{member.slug}"

    get root_path
    assert_response :success
    assert_select 'a[href="/choi-pd"]', count: 0
    assert_select "nav.impd-topnav-links a[href=?]", profile_path, text: "예시", count: 1
    assert_select "#impd-mobile-menu nav a[href=?]", profile_path, text: "예시", count: 1
    assert_select ".impd-hero-actions a[href=?]", profile_path, text: /예시 보기/, count: 1
    assert_select "#close a[href=?]", profile_path, text: "예시 보기", count: 1

    get profile_path
    assert_response :ok
  end

  test "example links use explore when all members are private" do
    Member.create!(name: "비공개 회원", email: "private-#{SecureRandom.hex(4)}@example.com",
      slug: "private-#{SecureRandom.hex(4)}", status: "pending_approval", password: "password1234")

    get root_path
    assert_response :success
    assert_select "nav.impd-topnav-links a[href=?]", explore_path, text: "예시", count: 1
    assert_select "#impd-mobile-menu nav a[href=?]", explore_path, text: "예시", count: 1
    assert_select "#people .impd-member-count", count: 0
    assert_select "#people .impd-member-grid > div", count: 3
  end
end
