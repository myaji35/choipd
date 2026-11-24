module BrandChannels
  class BlogPublishing
    def initialize(publisher: EgoProfile::NaverBlogPublisher.new)
      @publisher = publisher
    end

    def publish_due
      due_posts.order(:scheduled_at, :id).filter_map do |post|
        result = publish_post(post)
        [ post.id, result ] if result
      end
    end

    def publish_post(post)
      return unless post.approved_at && post.status_scheduled?

      candidate = due_posts.where(id: post.id, approved_at: post.approved_at)
      eligible = BrandChannel.where(platform: "naver_blog", session_status: "connected")
        .where.not(delegation_consent_at: nil).select(:id)
      claimed = candidate.where(brand_channel_id: eligible)
        .update_all(status: "publishing", updated_at: Time.current) == 1

      if claimed
        post.reload
        return unless post.status_publishing?

        reason = blocked_reason(post)
        return record_result(post, failure(reason)) if reason

        return record_result(post, @publisher.call(channel: post.brand_channel, title: post.title, body: post.message))
      end

      post.transaction do
        blocked = candidate.where.not(brand_channel_id: eligible)
        current = blocked.first
        if current && (reason = blocked_reason(current)) &&
            blocked.update_all(status: "failed", updated_at: Time.current) == 1
          record_result(current, failure(reason))
        end
      end
    end

    private

    def due_posts
      SnsScheduledPost.naver_blog_posts.due.where(published_at: nil).where.not(approved_at: nil)
    end

    def blocked_reason(post)
      channel = post.brand_channel
      return "브랜드 채널을 찾을 수 없습니다." unless channel
      return "브랜드 채널의 운영 위탁 동의가 필요합니다." unless channel.delegated?
      return "브랜드 채널의 네이버 로그인을 확인해 주세요." unless channel.session_status == "connected"
      return "네이버 블로그 채널을 선택해 주세요." unless channel.platform == "naver_blog"
      return "게시물과 같은 회원의 브랜드 채널을 선택해 주세요." if post.member_id && post.member_id != channel.brand.member_id
      return "글 제목 또는 본문을 확인해 주세요." if post.title.blank? || post.title.length > 100 || post.message.blank?

      nil
    end

    def failure(reason)
      { "ok" => false, "reason" => reason }
    end

    def record_result(post, result)
      published = result["ok"] == true
      status = published ? "published" : "failed"
      default_message = published ? "네이버 블로그에 게시했습니다." : "네이버 블로그 게시에 실패했습니다."
      post.transaction do
        # Record the outcome even if channel consent was withdrawn during publishing.
        post.update_columns(status: status, published_at: published ? Time.current : nil,
          published_url: published && !result["unconfirmed"] ? result["url"] : nil,
          result_message: result["reason"].presence || default_message, updated_at: Time.current)
        post.sns_post_histories.create!(action: "publish", status: status, response: result.to_json)
      end
      result
    end
  end
end
