require "test_helper"

class Linkedin::ActivityParserTest < ActiveSupport::TestCase
  test "matches posts and article URLs in document order" do
    text = file_fixture("linkedin/activity.txt").read
    links = JSON.parse(file_fixture("linkedin/activity_links.json").read)
    posts = Linkedin::ActivityParser.new(text, links).posts

    assert_equal 6, posts.size
    first = posts.first
    id = "7513750005350400000"
    assert_equal id, first[:activity_id]
    assert_equal "Data Pipelines That Explain Themselves", first[:title]
    assert_equal 24, first[:impressions]
    assert_equal links.first, first[:article_url]
    assert_equal links.second, first[:analytics_url]
    assert_equal "https://www.linkedin.com/feed/update/urn:li:activity:#{id}/", first[:post_url]
    assert_equal Time.at((id.to_i >> 22) / 1000.0).utc, first[:posted_at]
    assert_equal "한빛 데이터 노트", posts.fifth[:newsletter_name]
  end

  test "parses a block without links" do
    text = "피드 게시물\n홍길동\n2일 •\n게시물 제목\n홍길동\n노출 1,234\n"
    post = Linkedin::ActivityParser.new(text, nil).posts.sole

    assert_equal "게시물 제목", post[:title]
    assert_equal "2일 •", post[:relative_time]
    assert_equal 1234, post[:impressions]
    assert_nil post[:posted_at]
  end

  test "uses the first body line for a regular post" do
    text = "피드 게시물\n홍길동\n데이터 분석가\n3일 • \n첫 번째 본문 줄\n두 번째 본문 줄\n\u200b\n노출 12\n분석 보기\n스폰서로 등록"
    post = Linkedin::ActivityParser.new(text, []).posts.sole

    assert_equal "첫 번째 본문 줄", post[:title]
    assert_equal "post", post[:kind]
    assert_nil post[:newsletter_name]
    assert_equal 12, post[:impressions]
  end

  test "pairs unique activity IDs in order and uses each adjacent pulse link once" do
    text = file_fixture("linkedin/activity.txt").read
    pulse, first, other_pulse, second, _, third = JSON.parse(file_fixture("linkedin/activity_links.json").read)
    links = [ pulse, first, other_pulse, "#{first}?duplicate=1", pulse, second, third ]
    posts = Linkedin::ActivityParser.new(text, links).posts

    assert_equal [ first, second, third ], posts.first(3).pluck(:analytics_url)
    assert_equal [ pulse, nil, nil ], posts.first(3).pluck(:article_url)
    assert_equal "article", posts.first[:kind]
    assert_nil posts.fourth[:analytics_url]
  end
end
