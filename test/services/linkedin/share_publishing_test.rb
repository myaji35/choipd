require "test_helper"

class Linkedin::SharePublishingTest < ActiveSupport::TestCase
  setup do
    @account = ProfileAccount.create!(platform: "linkedin", display_name: "공유 계정")
  end

  test "only due approved LinkedIn shares are published and recorded" do
    due = scheduled_post
    unapproved = scheduled_post(approved_at: nil)
    future = scheduled_post(scheduled_at: 1.day.from_now)
    unrelated = scheduled_post(platform: "facebook")
    result = { "ok" => true, "url" => "https://www.linkedin.com/feed/update/urn:li:activity:42/" }
    service = publishing_service do |**payload|
      assert_equal({ kind: "post", account: @account, text: due.message }, payload)
      result
    end

    assert_equal [ [ due.id, result ] ], service.publish_due
    assert due.reload.status_published?
    assert due.published_at?
    assert_equal result["url"], due.published_url
    history = due.sns_post_histories.sole
    assert_equal [ "publish", "published", result ], [ history.action, history.status, JSON.parse(history.response) ]
    [ unapproved, future, unrelated ].each { |post| assert post.reload.status_scheduled? }
  end

  test "records failure and does not retry failed posts automatically" do
    record = scheduled_post
    failure = { "ok" => false, "reason" => "로그인 계정이 다름" }
    assert_equal failure, publishing_service { failure }.publish_post(record)
    assert record.reload.status_failed?
    assert_nil record.published_at
    assert_equal failure["reason"], record.result_message
    history = record.sns_post_histories.sole
    assert_equal [ "publish", "failed", failure ], [ history.action, history.status, JSON.parse(history.response) ]
    assert_empty publishing_service { flunk "unexpected retry" }.publish_due
  end

  test "unconfirmed posts and newsletters are locked against republication" do
    post = scheduled_post
    draft = @account.linkedin_newsletter_drafts.create!(title: "글", body: "본문")
    draft.update!(approved_at: Time.current)
    stale_post = SnsScheduledPost.find(post.id)
    stale_draft = LinkedinNewsletterDraft.find(draft.id)
    result = { "ok" => true, "url" => nil, "unconfirmed" => true, "reason" => "LinkedIn에서 게시 여부를 확인하세요." }
    service = publishing_service { result }

    freeze_time do
      assert_equal result, service.publish_post(post)
      assert_equal result, service.publish_newsletter(draft)
      [ post, draft ].each do |record|
        assert_equal "published", record.reload.status
        assert record.publishing_locked?
        assert_equal Time.current, record.published_at
        assert_nil record.published_url
        assert_equal result["reason"], record.result_message
      end
    end

    retry_service = publishing_service { flunk "unexpected republication" }
    assert_nil retry_service.publish_post(post)
    assert_nil retry_service.publish_post(stale_post)
    assert_nil retry_service.publish_newsletter(draft)
    assert_nil retry_service.publish_newsletter(stale_draft)
  end

  test "only the publishing claimant executes even with a stale scheduled copy" do
    record = scheduled_post
    stale = SnsScheduledPost.find(record.id)
    competing = publishing_service { flunk "duplicate publication" }
    winner = publishing_service do
      assert record.status_publishing?
      assert_nil competing.publish_post(stale)
      { "ok" => true }
    end
    assert_equal({ "ok" => true }, winner.publish_post(record))
    assert_equal 1, record.sns_post_histories.count
  end

  test "a stale approval cannot publish a changed post or newsletter" do
    record = scheduled_post
    stale = SnsScheduledPost.find(record.id)
    record.update!(message: "승인 후 수정")
    draft = @account.linkedin_newsletter_drafts.create!(title: "글", body: "본문")
    draft.update!(approved_at: Time.current)
    stale_draft = LinkedinNewsletterDraft.find(draft.id)
    draft.update!(body: "승인 후 수정")

    service = publishing_service { flunk "unexpected publication" }
    assert_nil service.publish_post(stale)
    assert_nil service.publish_newsletter(stale_draft)
    assert_nil service.publish_newsletter(draft)
  end

  private

  def scheduled_post(**attributes)
    @account.linkedin_share_posts.create!({
      platform: "linkedin", status: "scheduled", message: "게시물", scheduled_at: 1.minute.ago
    }.merge(attributes)).tap do |post|
      post.update!(approved_at: Time.current) unless attributes.key?(:approved_at)
    end
  end

  def publishing_service(&execute)
    publisher = Object.new
    publisher.define_singleton_method(:call) { |**payload| execute.call(**payload) }
    Linkedin::SharePublishing.new(publisher: publisher)
  end
end
