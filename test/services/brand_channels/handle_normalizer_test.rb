require "test_helper"

class BrandChannels::HandleNormalizerTest < ActiveSupport::TestCase
  test "계정 이름과 플랫폼 주소에서 이름을 정리해 기준 주소를 만든다" do
    [
      ["naver_blog", " @gagahoho_kang ", "gagahoho_kang", "https://blog.naver.com/gagahoho_kang"],
      ["naver_blog", "https://m.blog.naver.com/gagahoho_kang?x=1", "gagahoho_kang", "https://blog.naver.com/gagahoho_kang"],
      ["naver_blog", "blog.naver.com/abc#post", "abc", "https://blog.naver.com/abc"],
      ["instagram", "instagram.com/gagahoho_kang/", "gagahoho_kang", "https://www.instagram.com/gagahoho_kang/"],
      ["instagram", "https://www.instagram.com/my_photo/", "my_photo", "https://www.instagram.com/my_photo/"],
      ["facebook_page", "https://m.facebook.com/my-page/about", "my-page", "https://www.facebook.com/my-page"]
    ].each do |platform, input, handle, url|
      assert_equal({ handle: handle, profile_url: url }, normalize(platform, input))
      assert_equal url, BrandChannels::HandleNormalizer.canonical_url(platform, handle)
    end
  end

  test "직접 적은 주소를 유지하고 필요한 경우 이름을 뽑는다" do
    url = "https://m.blog.naver.com/abc"
    assert_equal({ handle: "abc", profile_url: url }, normalize("naver_blog", nil, url))

    url = "https://example.test/my-photo"
    assert_equal({ handle: "my-photo", profile_url: url }, normalize("instagram", "@my-photo/", url))
  end

  test "다른 플랫폼과 깨진 주소에서 이름을 뽑지 않는다" do
    url = "https://www.instagram.com/my_photo/"
    assert_equal url.delete_suffix("/"), normalize("naver_blog", url).fetch(:handle)
    assert_equal "", normalize("naver_blog", "", url).fetch(:handle)
    assert_equal "https://[", normalize("naver_blog", "https://[").fetch(:handle)
  end

  test "이름 없는 경로와 예약 경로는 빈 이름으로 처리한다" do
    %w[profile.php?id=1 pages/my-page p/my-page people/my-page].each do |path|
      assert_equal({ handle: "", profile_url: "" }, normalize("facebook_page", "facebook.com/#{path}"))
    end
    assert_equal({ handle: "", profile_url: "" }, normalize("facebook_page", "https://www.facebook.com/"))
  end

  test "다른 플랫폼은 앞뒤 공백만 없앤다" do
    assert_equal({ handle: "@name/", profile_url: "https://example.test/" },
      normalize("other", " @name/ ", " https://example.test/ "))
  end

  private

  def normalize(platform, handle, profile_url = nil)
    BrandChannels::HandleNormalizer.call(platform: platform, handle: handle, profile_url: profile_url)
  end
end
