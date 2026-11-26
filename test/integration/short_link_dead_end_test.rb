require "test_helper"

class ShortLinkDeadEndTest < ActionDispatch::IntegrationTest
  test "an unknown short code returns a not found page without a redirect" do
    get short_link_path(hash_code: "zzzzzzzz")

    assert_response :not_found
    assert_nil response.headers["Location"]
    assert_not_empty response.body
  end

  test "a valid short code permanently redirects and records the click" do
    link = ShortLink.resolve_or_create(target_path: "/")

    assert_difference -> { link.reload.click_count }, 1 do
      get short_link_path(hash_code: link.hash_code)
    end
    assert_response :moved_permanently
    assert_redirected_to root_path
  end
end
