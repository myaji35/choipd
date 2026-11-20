require "test_helper"

class BrandOps::WeeklyStatsTest < ActiveSupport::TestCase
  test "Korean weeks, activity, visits and small counts" do
    now = Time.find_zone!("Asia/Seoul").parse("2026-11-18 12:00")
    member = Member.create!(name: "테스트", email: "ops-test@example.com", slug: "ops-test", status: "approved", created_at: now - 40.days, updated_at: now - 40.days)
    MemberPost.create!(member: member, title: "소식", content: "내용", is_published: 1, published_at: now - 1.day)
    AnalyticsEvent.create!(event_name: "page_view", event_category: "test", page_path: "/ops-test", created_at: now - 1.day)
    AnalyticsEvent.create!(event_name: "page_view", event_category: "test", page_path: "/ops-test", user_agent: "Googlebot", created_at: now - 1.day)
    series = BrandOps::WeeklyStats.member(member, weeks: 2, now: now)
    assert_equal Date.new(2026, 11, 16), series.last[:week_start]
    assert_equal 1, series.last[:members_active]
    assert_equal 1, series.last[:visits]
    assert_equal "3건 미만", BrandOps::Display.count(2)
    assert_equal "0", BrandOps::Display.count(0)
    assert_equal "1,000", BrandOps::Display.count(1000)
  end
end

class BrandOpsExportTest < ActiveSupport::TestCase
  test "export contains aggregate data without email" do
    require "rake"
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    member = Member.create!(name: "내보내기", email: "private-export@example.com", slug: "ops-export", status: "approved")
    task = Rake::Task["impd:export_activity"]
    task.reenable
    output, = capture_io { task.invoke(member.slug) }
    json = JSON.parse(output)
    assert_equal member.slug, json["slug"]
    assert_equal 26, json.fetch("member").size
    assert_not_includes output, member.email
  end
end
