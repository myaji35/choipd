require "test_helper"

class Linkedin::DashboardParserTest < ActiveSupport::TestCase
  test "reads the six metrics and weekly progress" do
    text = file_fixture("linkedin/dashboard.txt").read
    parser = Linkedin::DashboardParser.new(text)
    metrics = parser.metrics

    assert_equal [ 26, 17, 7, 3, 0, 1 ], metrics.values.map { |metric| metric[:value] }
    assert_equal 767, metrics[:post_impressions_7d][:linkedin_change_pct]
    assert_equal 50, metrics[:newsletter_subscribers_7d][:linkedin_change_pct]
    assert_equal "11월 10일–16", metrics[:search_appearances][:period]
    assert_equal({ range: "11월 18일–11월 24일", posted: false, commented: false }, parser.weekly)
  end

  test "handles blank text, thousands separators and negative changes" do
    assert_nil Linkedin::DashboardParser.new(nil).weekly
    metrics = Linkedin::DashboardParser.new("1,234\n\n총 팔로워\n\n-4 ​%").metrics
    assert_equal 1234, metrics[:followers_total][:value]
    assert_equal(-4, metrics[:followers_total][:linkedin_change_pct])
    assert_nil metrics[:newsletter_views_7d][:value]
  end

  test "leaves weekly statuses unknown when the section is empty" do
    parser = Linkedin::DashboardParser.new("주간 진행 상황\n11월 18일–11월 24일")

    assert_equal({ range: "11월 18일–11월 24일", posted: nil, commented: nil }, parser.weekly)
  end

  test "uses evidence within the first twelve weekly lines" do
    text = [ "주간 진행 상황", "이번 주", "피드에 글을 올렸습니다", *Array.new(11, "활동"), "댓글을 남겼습니다" ].join("\n")

    assert_equal({ range: "이번 주", posted: true, commented: nil }, Linkedin::DashboardParser.new(text).weekly)
  end
end
