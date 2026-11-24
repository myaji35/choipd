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
end
