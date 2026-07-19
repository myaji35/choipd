class SnsScheduledPublishJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 30.seconds, attempts: 3

  def perform
    SnsScheduledPost.due.includes(:sns_account, :member).find_each do |post|
      publish_one(post)
    end
  end

  private

  def publish_one(post)
    account = post.sns_account
    unless account
      record_failure(post, { error: "no_account" })
      return
    end

    return unless post.platform == "facebook"

    result = FacebookOauth.publish_to_page(
      page_id: account.external_id,
      page_access_token: account.access_token,
      message: post.message
    )

    if result[:success]
      post.update!(status: "published")
      SnsPostHistory.create!(
        sns_scheduled_post: post,
        action: "publish",
        status: "published",
        response: result.to_json
      )
    else
      record_failure(post, result)
    end
  rescue StandardError => error
    safely_record_failure(post, { error: error.class.name })
  end

  def record_failure(post, response)
    post.update!(status: "failed")
    SnsPostHistory.create!(
      sns_scheduled_post: post,
      action: "publish",
      status: "failed",
      response: response.to_json
    )
  end

  def safely_record_failure(post, response)
    record_failure(post, response)
  rescue StandardError => error
    Rails.logger.error("Scheduled SNS post failure could not be recorded: post_id=#{post.id}, error=#{error.class.name}")
  end
end
