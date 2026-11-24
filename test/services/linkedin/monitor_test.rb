require "test_helper"

class Linkedin::MonitorTest < ActiveSupport::TestCase
  test "compares different Seoul dates for metrics and previous snapshots for posts" do
    travel_to Time.utc(2026, 11, 24, 15, 30) do
      dashboard = file_fixture("linkedin/dashboard.txt").read
      activity = file_fixture("linkedin/activity.txt").read
      links = JSON.parse(file_fixture("linkedin/activity_links.json").read)
      recent_id = (2.days.ago.to_i * 1000) << 22
      links[1] = links[1].sub("7513750005350400000", recent_id.to_s)
      newest = snapshot(Time.current, dashboard, activity, links)
      same_day = snapshot(15.minutes.ago, dashboard.sub("26", "25"), activity.sub("노출 24", "노출 20"), links)
      previous_day = snapshot(1.hour.ago, dashboard.sub("26", "23"), activity, links)
      monitor = Linkedin::Monitor.new([ newest, same_day, previous_day ])

      metric = monitor.latest_metrics[:post_impressions_7d]
      assert_equal 26, metric[:value]
      assert_equal 3, metric[:delta]
      assert_equal [ Date.new(2026, 11, 25), Date.new(2026, 11, 24) ], monitor.daily_series.pluck(:date)
      assert_equal [ 26, 23 ], monitor.daily_series.map { |row| row[:values][:post_impressions_7d] }
      assert_equal 4, monitor.posts.first[:impressions_delta]

      recommendation = monitor.weekly_recommendation
      assert_equal true, recommendation[:posted_last_7_days]
      assert_equal false, recommendation[:linkedin_weekly][:posted]
      assert_equal false, recommendation[:linkedin_weekly][:commented]
      assert recommendation[:message].present?
    end
  end

  test "safely handles empty, legacy and failed snapshots" do
    legacy = ProfileSnapshot.new(captured_at: Time.current, data: { "miniProfile" => {} })
    failure = ProfileSnapshot.new(captured_at: Time.current, data: { "pages" => { "dashboard" => { "error" => "timeout" } } })

    [ [], [ legacy ], [ failure, legacy ] ].each do |snapshots|
      monitor = Linkedin::Monitor.new(snapshots)
      assert_nil monitor.latest_metrics[:followers_total][:value]
      assert_nil monitor.latest_metrics[:followers_total][:delta]
      assert_empty monitor.posts
      assert_nil monitor.weekly_recommendation[:linkedin_weekly]
      assert_equal false, monitor.weekly_recommendation[:posted_last_7_days]
    end
  end

  test "uses the newest valid page independently and skips failed comparison pages" do
    travel_to Time.utc(2026, 11, 24, 15, 30) do
      id = (2.days.ago.to_i * 1000) << 22
      links = [ "https://www.linkedin.com/analytics/post-summary/urn:li:activity:#{id}/" ]
      activity = "피드 게시물\n홍길동\n2일 •\n본문\n노출 12"
      newest = snapshot(Time.current, "99\n총 팔로워", activity, links)
      newest.data["pages"]["dashboard"]["error"] = "timeout"
      valid_dashboard = snapshot(5.minutes.ago, "17\n총 팔로워\n주간 진행 상황\n이번 주", nil, links)
      same_day = snapshot(10.minutes.ago, "16\n총 팔로워", activity.sub("12", "8"), links)
      previous_day = snapshot(1.hour.ago, "14\n총 팔로워", activity, links)
      monitor = Linkedin::Monitor.new([ newest, valid_dashboard, same_day, previous_day ])

      assert_equal 17, monitor.latest_metrics[:followers_total][:value]
      assert_equal 3, monitor.latest_metrics[:followers_total][:delta]
      assert_equal [ 17, 14 ], monitor.daily_series.map { |row| row[:values][:followers_total] }
      assert_equal 4, monitor.posts.sole[:impressions_delta]
      assert_equal "최근 7일 안에 게시했습니다. 댓글 정보는 다음 점검 때 확인합니다.", monitor.weekly_recommendation[:message]
    end
  end

  test "compares the newest network sample with the previous Seoul date and limits its series to 30 days" do
    travel_to Time.utc(2026, 11, 24, 15, 30) do
      samples = [
        ProfileSnapshot.new(captured_at: Time.current, data: { "pages" => { "network" => { "error" => "timeout" } } }),
        network_snapshot(5.minutes.ago, 15, 3),
        network_snapshot(15.minutes.ago, 14, 2),
        network_snapshot(1.hour.ago, 12, 1),
        network_snapshot(30.days.ago, 6, 0)
      ]
      monitor = Linkedin::Monitor.new(samples)

      assert_equal 15, monitor.latest_network[:connections]
      assert_equal 3, monitor.latest_network[:deltas][:connections]
      assert_equal 2, monitor.latest_network[:deltas][:unread_notifications]
      assert_equal [
        { date: Date.new(2026, 11, 25), values: { connections: 15, following: 9, invitations_sent: 12 } },
        { date: Date.new(2026, 11, 24), values: { connections: 12, following: 9, invitations_sent: 12 } }
      ], monitor.network_series
    end
  end

  test "compares newsletter counts across Seoul dates and matches latest article impressions by URL" do
    travel_to Time.utc(2026, 11, 24, 15, 30) do
      url = "https://www.linkedin.com/newsletters/dev-notes-123/"
      articles = JSON.parse(file_fixture("linkedin/newsletter_page_links.json").read)
      editions = file_fixture("linkedin/newsletter_page.txt").read
      samples = [ [ Time.current, 6 ], [ 15.minutes.ago, 5 ], [ 1.hour.ago, 4 ], [ 30.days.ago, 2 ] ].map do |captured_at, count|
        ProfileSnapshot.new(captured_at: captured_at, data: {
          "pages" => {
            "newsletters" => { "text" => "Dev Notes · 글쓴이\n구독자 #{count}", "links" => [ url ] },
            "newsletter_pages" => [ { "url" => url, "text" => editions.sub("구독자 6명", "구독자 #{count}명"), "links" => articles } ]
          }
        })
      end
      samples.first.data["pages"]["activity"] = {
        "text" => "피드 게시물\n홍길동\n2일 •\nDev Notes\nArticle\n홍길동\n노출 12",
        "links" => [ "#{URI::DEFAULT_PARSER.unescape(articles.first)}/?trk=activity", "https://www.linkedin.com/analytics/post-summary/urn:li:activity:7513750005350400000/" ]
      }

      monitor = Linkedin::Monitor.new(samples)
      newsletter = monitor.newsletters.sole
      assert_equal 2, newsletter[:subscribers_delta]
      assert_equal [ 12, nil ], newsletter[:editions].pluck(:impressions)
      assert_equal [
        { date: Date.new(2026, 11, 25), values: { "Dev Notes" => 6 } },
        { date: Date.new(2026, 11, 24), values: { "Dev Notes" => 4 } }
      ], monitor.newsletter_series
    end
  end

  private

  def network_snapshot(captured_at, connections, notifications)
    ProfileSnapshot.new(captured_at: captured_at, data: {
      "pages" => { "network" => { "text" => "12\n초대 보냄\n#{connections}\n1촌\n9\n팔로우중" } },
      "nav_badges" => { "notifications" => notifications }
    })
  end

  def snapshot(captured_at, dashboard, activity, links)
    ProfileSnapshot.new(captured_at: captured_at, data: {
      "pages" => {
        "dashboard" => { "text" => dashboard },
        "activity" => { "text" => activity, "links" => links }
      }
    })
  end
end
