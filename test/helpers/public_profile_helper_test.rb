require "test_helper"

class PublicProfileHelperTest < ActionView::TestCase
  test "moments heading reflects the photo categories" do
    {
      ["workshop"] => "작업 사진",
      %w[workshop product] => "작업 사진",
      ["daily"] => "일상 장면",
      ["people"] => "일상 장면",
      [nil] => "일상 장면",
      [""] => "일상 장면",
      [] => "일상 장면",
      %w[workshop daily] => "사진",
      ["press"] => "사진"
    }.each do |categories, heading|
      photos = categories.map { |category| MemberPhoto.new(category: category) }
      assert_equal heading, moments_heading(photos), categories.inspect
    end
  end

  test "member photo category options preserve legacy selections" do
    options = [["일상", "daily"], ["작업", "workshop"], ["이력", "press"]]
    assert_equal options, member_photo_category_options
    assert_equal options + [["작품", "product"]], member_photo_category_options("product")
    assert_equal options + [["일상", "people"]], member_photo_category_options("people")
  end

  test "treats a JPG URL with Korean characters and a space as an image" do
    url = "https://a.com/한글 사진.jpg?size=large#preview"

    assert_equal({ media_url: url }, portfolio_media(MemberPortfolioItem.new(media_url: url)))
  end

  test "treats a host-only URL as a link and extracts its host" do
    url = "https://townin.net"

    assert_equal({ link_url: url, link_host: "townin.net" }, portfolio_media(MemberPortfolioItem.new(media_url: url)))
  end

  test "treats an Active Storage path without a file extension as an image" do
    ["/rails/active_storage/blobs/redirect/token", "https://a.com/rails/active_storage/blobs/redirect/token"].each do |url|
      assert_equal({ media_url: url }, portfolio_media(MemberPortfolioItem.new(media_url: url)))
    end
  end

  test "respects explicit link media type on an image URL and extracts the host when URI parsing fails" do
    url = "https://a.com/한글 사진.jpg"
    item = MemberPortfolioItem.new(media_url: url, media_type: "link")

    assert_equal({ link_url: url, link_host: "a.com" }, portfolio_media(item))
  end
end
