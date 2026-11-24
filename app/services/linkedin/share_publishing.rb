module Linkedin
  class SharePublishing
    def initialize(publisher: EgoProfile::LinkedinPublisher.new)
      @publisher = publisher
    end

    def publish_post(post)
      return unless post.linkedin_share? && post.approved_at && post.status_scheduled? &&
        post.scheduled_at && post.scheduled_at <= Time.current && post.published_at.nil?

      claim = due_posts.where(id: post.id, approved_at: post.approved_at)
      return unless claim.update_all(status: "publishing", updated_at: Time.current) == 1

      post.reload
      result = @publisher.call(kind: "post", account: post.profile_account, text: post.message)
      post.transaction do
        record_result(post, result)
        post.sns_post_histories.create!(action: "publish", status: post.status, response: result.to_json)
      end
      result
    end

    def publish_due
      due_posts.order(:scheduled_at, :id).filter_map do |post|
        result = publish_post(post)
        [ post.id, result ] if result
      end
    end

    def publish_newsletter(draft)
      return unless draft.approved_at && !draft.publishing_locked? && draft.status.in?(%w[draft failed])

      claim = LinkedinNewsletterDraft.where(id: draft.id, status: %w[draft failed],
        published_at: nil, approved_at: draft.approved_at)
      return unless claim.update_all(status: "publishing", updated_at: Time.current) == 1

      draft.reload
      result = @publisher.call(kind: "article", account: draft.profile_account,
        title: draft.title, body: draft.body, newsletter_name: draft.newsletter_name)
      record_result(draft, result)
      result
    end

    private

    def due_posts
      SnsScheduledPost.linkedin_shares.due.where(published_at: nil).where.not(approved_at: nil)
    end

    def record_result(record, result)
      if result["unconfirmed"]
        record.update!(status: "published", published_at: Time.current, published_url: nil, result_message: result["reason"])
      elsif result["ok"] == true
        record.update!(status: "published", published_at: Time.current, published_url: result["url"],
          result_message: result["reason"].presence || "LinkedIn에 게시했습니다.")
      else
        record.update!(status: "failed", result_message: result["reason"].presence || "LinkedIn 게시에 실패했습니다.")
      end
    end
  end
end
