require "test_helper"

class LineiconsTest < ActionDispatch::IntegrationTest
  test "home and approved public profile render icons" do
    member = Member.create!(name: "테스트 회원", email: "lineicons@example.com", slug: "lineicons-test", status: "approved")
    get "/"
    assert_response :success
    assert_includes response.body, "lni "
    get "/#{member.slug}"
    assert_response :success
    assert_includes response.body, "lni "
  end
end
