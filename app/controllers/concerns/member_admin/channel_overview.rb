module MemberAdmin::ChannelOverview
  extend ActiveSupport::Concern

  CHANNEL_PLATFORMS = {
    "naver_blog" => "네이버 블로그",
    "facebook_page" => "페이스북",
    "instagram" => "인스타그램"
  }.freeze

  private

  def build_channel_overview(detail: false)
    brands = @member.brands.personal_first.includes(brand_channels: :sns_account).to_a
    channels_by_platform = brands.flat_map do |brand|
      brand.brand_channels.filter_map { |channel| [ channel, brand ] if CHANNEL_PLATFORMS.key?(channel.platform) }
    end.sort_by { |channel, brand| [ brand.personal? ? 0 : 1, channel.id ] }
      .group_by { |channel, _brand| channel.platform }
    now = Time.current.in_time_zone("Asia/Seoul")

    CHANNEL_PLATFORMS.flat_map do |platform, label|
      channels_by_platform.fetch(platform) { [ [ nil, brands.first ] ] }.map do |channel, brand|
        item = { platform: platform, label: label, channel: channel, brand: brand }
        populate_channel_overview(item, now: now, detail: detail)
      end
    end
  end

  def populate_channel_overview(item, now:, detail:)
    channel = item[:channel]
    account = channel&.sns_account
    posts = channel ? SnsScheduledPost.where(brand_channel_id: channel.id) : SnsScheduledPost.none
    posts = posts.or(SnsScheduledPost.where(sns_account_id: channel.sns_account_id)) if channel&.sns_account_id
    posted = posts.where(status: "published").or(posts.where.not(published_at: nil))
    posted = posted.order(Arel.sql("COALESCE(published_at, scheduled_at) DESC"))
    scheduled = posts.where(status: "scheduled", published_at: nil)
    last_post = posted.first
    steps = [ [ "채널 등록", channel.present? ], [ "운영 위탁 동의", channel&.delegated? || false ], [ "글 올리는 중", last_post.present? ] ]

    item.merge!(
      posted_30d: posted.where("COALESCE(published_at, scheduled_at) BETWEEN ? AND ?", now - 30.days, now).count,
      last_posted_at: last_post&.published_at || last_post&.scheduled_at,
      scheduled_count: scheduled.count,
      next_scheduled_at: scheduled.minimum(:scheduled_at),
      ever_posted: last_post.present?,
      followers: account&.follower_count,
      follower_delta: account&.follower_delta,
      steps: steps,
      state: channel_overview_state(channel, steps)
    )
    if detail
      item.merge!(
        recent_posts: posted.limit(10).to_a,
        scheduled_posts: scheduled.order(:scheduled_at).limit(10).to_a,
        follower_snapshots: account ? account.sns_follower_snapshots.recent.limit(5).to_a : []
      )
    end
    item
  end

  def channel_overview_state(channel, steps)
    return :missing unless channel
    return :checking if %w[error logged_out].include?(channel.session_status)
    return :running if steps.all?(&:last)

    :preparing
  end
end
