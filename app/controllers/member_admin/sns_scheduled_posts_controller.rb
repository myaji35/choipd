class MemberAdmin::SnsScheduledPostsController < MemberAdmin::BaseController
  def index
    load_index_data
  end

  def create
    account = active_facebook_account
    unless account
      redirect_to scheduled_posts_path, alert: "먼저 페이스북 페이지를 연결해주세요."
      return
    end

    scheduled_at = parse_scheduled_at
    unless scheduled_at&.future?
      redirect_to scheduled_posts_path, alert: "예약 시각은 현재보다 미래여야 합니다."
      return
    end

    post = @member.sns_scheduled_posts.create(
      sns_account: account,
      message: scheduled_post_params[:message],
      platform: "facebook",
      scheduled_at: scheduled_at,
      status: "scheduled"
    )

    if post.persisted?
      redirect_to scheduled_posts_path, notice: "SNS 포스트 발행을 예약했습니다."
    else
      redirect_to scheduled_posts_path, alert: post.errors.full_messages.join(", ")
    end
  end

  def destroy
    post = @member.sns_scheduled_posts.find(params[:id])

    if post.status_scheduled?
      post.destroy!
      redirect_to scheduled_posts_path, notice: "예약 발행을 취소했습니다."
    else
      redirect_to scheduled_posts_path, alert: "예약 상태인 포스트만 취소할 수 있습니다."
    end
  end

  private

  def load_index_data
    @scheduled = @member.sns_scheduled_posts.recent
    @account = active_facebook_account
  end

  def active_facebook_account
    @member.sns_accounts.active.where(platform: "facebook").first
  end

  def scheduled_post_params
    params.require(:sns_scheduled_post).permit(:message, :scheduled_at)
  end

  def parse_scheduled_at
    Time.zone.parse(scheduled_post_params[:scheduled_at].to_s)
  rescue ArgumentError
    nil
  end

  def scheduled_posts_path
    slug_admin_scheduled_posts_path(slug: @member.slug)
  end
end
