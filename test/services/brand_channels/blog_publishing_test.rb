require "test_helper"

class BrandChannels::BlogPublishingTest < ActiveSupport::TestCase
  setup do
    @brand = Brand.create!(name: "게시 브랜드")
    @channel = @brand.brand_channels.create!(platform: "naver_blog", account_handle: "my-blog",
      ego_server_name: "m6.brand", delegation_consent_at: Time.current, session_status: "connected")
  end

  test "publishes only due approved posts and passes account and server name to Ego" do
    due = scheduled_post
    unapproved = scheduled_post(approved: false)
    future = scheduled_post(scheduled_at: 1.day.from_now)
    stale = SnsScheduledPost.find(due.id)
    result = { "ok" => true, "url" => "https://blog.naver.com/my-blog/123" }
    service = publishing_service do |script, timeout:, server_name:|
      assert due.reload.status_publishing?
      competing = publishing_service { flunk "duplicate publication" }
      assert_nil competing.publish_post(stale)
      input = JSON.parse(script.lines.first.delete_prefix("const PUBLISH = ").strip.delete_suffix(";"))
      assert_equal({ "account_handle" => "my-blog", "title" => due.title, "body" => due.message, "probe" => false }, input)
      assert_equal "m6.brand", server_name
      assert_equal 240, timeout
      result
    end

    assert_equal [ [ due.id, result ] ], service.publish_due
    assert due.reload.status_published?
    assert due.published_at?
    assert_equal result["url"], due.published_url
    assert_history due, result
    [ unapproved, future ].each { |post| assert post.reload.status_scheduled? }
  end

  test "records missing delegation and disconnected sessions without invoking Ego" do
    revoked = scheduled_post
    disconnected_channel = @brand.brand_channels.create!(platform: "naver_blog",
      delegation_consent_at: Time.current, session_status: "logged_out")
    disconnected = scheduled_post(brand_channel: disconnected_channel)
    @channel.update!(delegation_consent_at: nil)

    results = publishing_service { flunk "blocked publication" }.publish_due.to_h
    assert_equal "브랜드 채널의 운영 위탁 동의가 필요합니다.", results.fetch(revoked.id)["reason"]
    assert_equal "브랜드 채널의 네이버 로그인을 확인해 주세요.", results.fetch(disconnected.id)["reason"]
    [ revoked, disconnected ].each do |post|
      result = results.fetch(post.id)
      assert post.reload.status_failed?
      assert_nil post.published_at
      assert_equal result["reason"], post.result_message
      assert_history post, result
    end
  end

  test "records unconfirmed clicks as published and skips automatic republication" do
    post = scheduled_post
    result = { "ok" => true, "unconfirmed" => true, "reason" => "네이버 블로그에서 확인하세요." }
    service = publishing_service { result }

    assert_equal result, service.publish_post(post)
    assert post.reload.status_published?
    assert post.published_at?
    assert_nil post.published_url
    assert_equal result["reason"], post.result_message
    assert_history post, result
    assert_empty service.publish_due
  end

  test "records a known failure and skips automatic retries" do
    post = scheduled_post
    result = { "ok" => false, "reason" => "로그인 계정 불일치" }
    service = publishing_service { result }

    assert_equal result, service.publish_post(post)
    assert post.reload.status_failed?
    assert_nil post.published_at
    assert_equal result["reason"], post.result_message
    assert_history post, result
    assert_empty service.publish_due
  end

  test "changing message title or schedule clears approval and prevents stale publication" do
    [ { message: "수정 본문" }, { title: "수정 제목" }, { scheduled_at: 2.minutes.ago } ].each do |changes|
      post = scheduled_post
      stale = SnsScheduledPost.find(post.id)
      post.update!(changes)

      assert_nil post.approved_at
      assert post.status_draft?
      assert_nil publishing_service { flunk "stale approval" }.publish_post(stale)
    end
  end

  private

  def scheduled_post(approved: true, **attributes)
    SnsScheduledPost.create!({
      brand_channel: @channel, platform: "naver_blog", title: "제목", message: "본문",
      scheduled_at: 1.minute.ago, status: "scheduled"
    }.merge(attributes)).tap do |post|
      post.update!(approved_at: Time.current) if approved
    end
  end

  def publishing_service(&run_script)
    runner = Object.new
    runner.define_singleton_method(:run_script) { |*args, **kwargs| run_script.call(*args, **kwargs) }
    BrandChannels::BlogPublishing.new(publisher: EgoProfile::NaverBlogPublisher.new(runner: runner))
  end

  def assert_history(post, result)
    history = post.sns_post_histories.sole
    assert_equal [ "publish", post.status, result ], [ history.action, history.status, JSON.parse(history.response) ]
  end
end
