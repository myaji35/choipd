class MemberAdmin::SnsPublishesController < MemberAdmin::BaseController
  def facebook
    account = @member.sns_accounts.active.where(platform: "facebook").first
    unless account
      redirect_to sns_accounts_path, alert: "먼저 페이스북 페이지를 연결해주세요."
      return
    end

    if account.external_id.blank?
      redirect_to sns_accounts_path, alert: "페이지 재연결이 필요합니다."
      return
    end

    message = params[:message].to_s.strip
    if message.blank?
      redirect_to sns_accounts_path, alert: "발행할 내용을 입력해주세요."
      return
    end

    scheduled_post = @member.sns_scheduled_posts.build(
      sns_account: account,
      message: message,
      platform: "facebook",
      scheduled_at: Time.current
    )
    unless scheduled_post.valid?
      redirect_to sns_accounts_path, alert: scheduled_post.errors.full_messages.join(", ")
      return
    end

    result = FacebookOauth.publish_to_page(
      page_id: account.external_id,
      page_access_token: account.access_token,
      link: params[:link].presence,
      message: message
    )

    scheduled_post.update!(status: result[:success] ? "published" : "failed")
    scheduled_post.sns_post_histories.create!(
      action: "publish",
      status: result[:success] ? "success" : "failed",
      response: result.to_json
    )

    if result[:success]
      redirect_to sns_accounts_path, notice: "페이스북에 발행되었습니다."
    else
      redirect_to sns_accounts_path, alert: result[:error]
    end
  end

  private

  def sns_accounts_path
    slug_admin_sns_accounts_path(slug: @member.slug)
  end
end
