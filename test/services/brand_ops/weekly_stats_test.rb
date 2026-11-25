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

  setup do
    @now = Time.find_zone!("Asia/Seoul").local(2026, 11, 25, 12)
    @blog_owner = Member.create!(name: "블로그 회원", email: "weekly-blog@example.com", slug: "weekly-blog", status: "approved")
    brand = @blog_owner.brands.create!(name: "개인 브랜드", personal: true)
    channel = brand.brand_channels.create!(platform: "naver_blog", delegation_consent_at: @now - 1.week)
    @blog_post = SnsScheduledPost.create!(brand_channel: channel, platform: "naver_blog", title: "블로그 글", message: "블로그 글",
      status: "published", scheduled_at: @now - 1.day, published_at: @now - 1.day)
  end

  test "채널로 올린 글은 기록 상태가 published 여도 SNS에 올린 글로 센다" do
    SnsPostHistory.create!(sns_scheduled_post: @blog_post, status: "published", created_at: @blog_post.published_at)

    assert_equal 1, BrandOps::WeeklyStats.member(@blog_owner, now: @now).last[:sns_posts]
  end

  test "기록이 없는 올린 글도 한 번 센다" do
    assert_equal 1, BrandOps::WeeklyStats.member(@blog_owner, now: @now).last[:sns_posts]
  end

  test "다른 회원의 글은 세지 않는다" do
    other = Member.create!(name: "다른 회원", email: "other-blog@example.com", slug: "other-blog", status: "approved")

    assert_equal 0, BrandOps::WeeklyStats.member(other, now: @now).last[:sns_posts]
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
