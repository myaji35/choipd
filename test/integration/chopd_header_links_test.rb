require "test_helper"

class ChopdHeaderLinksTest < ActionDispatch::IntegrationTest
  test "guest header links point to working destinations" do
    get education_path
    assert_response :ok

    hrefs = css_select("header a[href], #mobile-nav a[href]").map { |link| link["href"] }
    assert_empty hrefs.select { |href| href.start_with?("#") }

    [ ".nav-links-desktop", "#mobile-nav" ].each do |selector|
      assert_select "#{selector} a[href]", text: "소개", count: 1 do |links|
        assert_equal media_greeting_path, links.first["href"]
      end
    end

    hrefs.uniq.select { |href| href.start_with?("/") && !href.start_with?("//") }.each do |href|
      get href
      assert response.status == 200 || response.status.between?(300, 399),
        "Expected GET #{href} to return 200 or 3xx, got #{response.status}"
    end
  end
end
