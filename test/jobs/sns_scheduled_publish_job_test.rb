require "test_helper"

class SnsScheduledPublishJobTest < ActiveJob::TestCase
  test "leaves LinkedIn shares for the approval-gated publisher" do
    account = ProfileAccount.create!(platform: "linkedin", display_name: "공유 계정")
    post = account.linkedin_share_posts.create!(platform: "linkedin", message: "승인됨",
      scheduled_at: 1.minute.ago, status: "scheduled")
    post.update!(approved_at: Time.current)

    SnsScheduledPublishJob.perform_now

    assert post.reload.status_scheduled?
    assert_empty post.sns_post_histories
  end

  test "leaves brand channel posts for the Ego publisher" do
    brand = Brand.create!(name: "게시 브랜드")
    channel = brand.brand_channels.create!(platform: "naver_blog", delegation_consent_at: Time.current)
    post = SnsScheduledPost.create!(platform: "naver_blog", brand_channel: channel, title: "제목", message: "본문",
      scheduled_at: 1.minute.ago, status: "scheduled")
    post.update!(approved_at: Time.current)

    SnsScheduledPublishJob.perform_now

    assert post.reload.status_scheduled?
    assert_empty post.sns_post_histories
  end
end
