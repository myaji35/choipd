require "test_helper"

class ProfileAccounts::WeeklyReportTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 11, 23, 15, 30)
    @linkedin = ProfileAccount.create!(platform: "linkedin", display_name: "가상 인물")
    @start = Time.utc(2026, 11, 17, 15)
    @cutoff = Time.utc(2026, 11, 24, 15)
    @dashboard = file_fixture("linkedin/dashboard.txt").read
  end

  test "uses the newest snapshot strictly before Seoul week start and excludes next midnight" do
    dashboard_snapshot(@start - 2.seconds, 18)
    dashboard_snapshot(@start - 1.second, 23)
    dashboard_snapshot(@start, 24)
    dashboard_snapshot(@cutoff - 1.second, 26)
    dashboard_snapshot(@cutoff, 999)

    report = ProfileAccounts::WeeklyReport.new
    assert_equal Date.new(2026, 11, 18), report.to_h[:week_start]
    assert_equal Date.new(2026, 11, 24), report.to_h[:week_end]
    metrics = report.to_h[:linkedin].sole[:metrics]
    assert_equal 6, metrics.size
    assert_equal [ 23, 26, 3 ], metrics[:post_impressions_7d].values_at(:start, :end, :delta)
    assert_includes report.to_text, "7일 동안 게시물 노출수 26 (+3)"
  end

  test "uses oldest in-week snapshot if there is no earlier one and omits self comparison" do
    dashboard_snapshot(@start, 21)
    assert_equal [ nil, 21, nil ], impressions.values_at(:start, :end, :delta)
    dashboard_snapshot(@start + 1.hour, 24)
    dashboard_snapshot(Time.current, 26)
    assert_equal [ 21, 26, 5 ], impressions.values_at(:start, :end, :delta)
  end

  test "ignores earlier snapshots when neither account has an in-week snapshot" do
    dashboard_snapshot(@start - 1.second, 17)
    naver = ProfileAccount.create!(platform: "naver_people", display_name: "네이버 계정")
    naver.profile_snapshots.create!(captured_at: @start - 1.second, data: {
      "people" => { "name" => "이전 이름" }, "applications" => { "ING" => [], "END" => [] }
    })

    report = ProfileAccounts::WeeklyReport.new
    linkedin = report.to_h[:linkedin].sole
    naver = report.to_h[:naver_people].sole
    assert_equal false, linkedin[:has_snapshot]
    assert_equal false, naver[:has_snapshot]
    assert_equal [ nil, nil, nil ], linkedin[:metrics][:post_impressions_7d].values_at(:start, :end, :delta)
    assert_equal [ nil, nil, nil ], linkedin[:network][:connections].values_at(:start, :end, :delta)
    assert_equal [ [], [] ], linkedin.values_at(:newsletters, :posts)
    assert_empty naver[:changes]
    assert_equal [ nil, nil, nil ], naver[:completeness].values_at(:start, :end, :delta)
    assert_equal [ nil, nil, [] ], naver[:applications].values_at(:in_progress, :completed, :changes)
    assert_includes report.to_text, "가상 인물\n이 기간의 사본이 없습니다."
    assert_includes report.to_text, "네이버 계정\n이 기간의 사본이 없습니다."
  end

  test "describes an unchanged count in text" do
    dashboard_snapshot(@start - 1.second, 17)
    dashboard_snapshot(@start, 17)

    assert_includes ProfileAccounts::WeeklyReport.new.to_text, "7일 동안 게시물 노출수 17 (변화 없음)"
  end

  test "skips bad pages independently and keeps the end snapshot badges" do
    linkedin_snapshot(@start - 4.seconds, "network" => { "text" => "12\n1촌" })
    dashboard_snapshot(@start - 3.seconds, 23)
    linkedin_snapshot(@start - 2.seconds, "dashboard" => { "text" => @dashboard, "error" => "timeout" })
    dashboard_snapshot(@start + 1.hour, 26)
    linkedin_snapshot(@start + 2.hours, "network" => { "text" => "15\n1촌" })
    @linkedin.profile_snapshots.create!(captured_at: Time.current, data: {
      "pages" => { "dashboard" => { "text" => "" }, "network" => { "error" => "timeout" } },
      "nav_badges" => { "messages" => 0, "notifications" => 3 }
    })

    report = linkedin_report
    assert_equal [ 23, 26, 3 ], report[:metrics][:post_impressions_7d].values_at(:start, :end, :delta)
    assert_equal [ 12, 15, 3 ], report[:network][:connections].values_at(:start, :end, :delta)
    assert_equal [ 0, 3 ], report[:network].values_at(:unread_messages, :unread_notifications)
    assert_equal false, report[:weekly_goal][:linkedin_weekly][:posted]
  end

  test "collects posts from older activity pages using Seoul boundaries and keeps newest duplicate" do
    activity = file_fixture("linkedin/activity.txt").read
    links = JSON.parse(file_fixture("linkedin/activity_links.json").read)
    [ @start, @start - 1.second, @cutoff ].each_with_index do |time, index|
      link_index = index * 2 + 1
      links[link_index] = links[link_index].sub(/activity:\d+/, "activity:#{(time.to_i * 1000) << 22}")
    end
    linkedin_snapshot(@start + 1.day, "activity" => { "text" => activity, "links" => links })
    linkedin_snapshot(@start + 2.days, "activity" => { "text" => activity.sub("노출 24", "노출 30"), "links" => links })
    linkedin_snapshot(Time.current, "activity" => { "error" => "timeout" })

    report = linkedin_report
    post = report[:posts].sole
    assert_equal @start, post[:posted_at]
    assert_equal "article", post[:kind]
    assert_equal 30, post[:impressions]
    assert_equal links.first, post[:url]
    assert report[:weekly_goal][:posted]
  end

  test "compares newsletter subscriber counts with the same parser as the account page" do
    url = "https://www.linkedin.com/newsletters/ximtier-dev-notes-7513833935739547648/"
    subscriber_url = "https://www.linkedin.com/newsletters/목표를-달성하는-협업의-힘-7018115202437054464/"
    [ [ @start - 1.second, 4 ], [ Time.current, 6 ] ].each do |time, subscribers|
      linkedin_snapshot(time,
        "newsletters" => { "text" => file_fixture("linkedin/newsletters.txt").read, "links" => [ url, subscriber_url ] },
        "newsletter_pages" => [ {
          "url" => url, "text" => file_fixture("linkedin/newsletter_page.txt").read.sub("구독자 6명", "구독자 #{subscribers}명"),
          "links" => JSON.parse(file_fixture("linkedin/newsletter_page_links.json").read)
        } ])
    end

    newsletters = linkedin_report[:newsletters]
    author = newsletters.find { |entry| entry[:role] == "author" }
    assert_equal [ "XimTier Dev Notes", 4, 6, 2 ], author.values_at(:name, :start_subscribers, :end_subscribers, :delta)
    assert_equal "목표를 달성하는 협업의 힘", newsletters.find { |entry| entry[:role] == "subscriber" }[:name]
  end

  test "reports Naver profile changes and application counts and status transitions" do
    account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물")
    old_application = { "applyId" => 2, "itemName" => "소속", "applyDate" => "2026-11-17", "statusName" => "접수" }
    account.profile_snapshots.create!(captured_at: @start - 1.second, data: {
      "people" => { "name" => "이전 이름" }, "applications" => { "ING" => [ old_application ], "END" => [] }
    })
    account.profile_snapshots.create!(captured_at: 1.hour.ago, data: {
      "people" => { "name" => "새 이름", "ename" => "New Name" },
      "applications" => {
        "ING" => { "content" => [ { "applyId" => 1, "itemName" => "직업", "applyDate" => "2026-11-23", "statusName" => "접수" } ] },
        "END" => [ old_application.merge("statusName" => "완료") ]
      }
    })
    account.profile_snapshots.create!(captured_at: Time.current, data: {
      "people" => { "error" => "timeout" }, "applications" => { "ING" => { "error" => "timeout" } }
    })

    report = ProfileAccounts::WeeklyReport.new
    naver = report.to_h[:naver_people].sole
    assert_equal [ 0, 10 ], naver[:completeness].values_at(:start, :end)
    assert_equal [ "이전 이름", "새 이름" ], naver[:changes].find { |change| change[:label] == "이름" }.values_at(:before, :after)
    assert_equal [ 1, 1 ], naver[:applications].values_at(:in_progress, :completed)
    assert_equal %w[new finished], naver[:applications][:changes].pluck(:kind)
    assert_includes report.to_text, "완성도 0% → 10%"
  end

  test "includes active accounts with no snapshots and obeys tenant scope" do
    dashboard_snapshot(@cutoff, 26)
    naver = ProfileAccount.create!(platform: "naver_people", display_name: "사본 없음", tenant_id: 2)
    ProfileAccount.create!(platform: "linkedin", display_name: "비활성 계정", is_active: false)
    report = ProfileAccounts::WeeklyReport.new

    assert_equal @linkedin.id, report.to_h[:linkedin].sole[:account_id]
    assert_equal false, report.to_h[:linkedin].sole[:has_snapshot]
    assert_empty report.to_h[:naver_people]
    assert_includes report.to_text, "이 기간의 사본이 없습니다."
    assert_equal naver.id, ProfileAccounts::WeeklyReport.new(tenant_id: 2).to_h[:naver_people].sole[:account_id]
  end

  private

  def linkedin_report
    ProfileAccounts::WeeklyReport.new.to_h[:linkedin].sole
  end

  def impressions
    linkedin_report[:metrics][:post_impressions_7d]
  end

  def linkedin_snapshot(time, pages)
    @linkedin.profile_snapshots.create!(captured_at: time, data: { "pages" => pages })
  end

  def dashboard_snapshot(time, impressions)
    linkedin_snapshot(time, "dashboard" => { "text" => @dashboard.sub("26", impressions.to_s) })
  end
end
