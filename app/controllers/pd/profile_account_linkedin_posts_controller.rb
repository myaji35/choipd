class Pd::ProfileAccountLinkedinPostsController < Pd::BaseController
  before_action :set_linkedin_account
  before_action :set_post, except: :create

  def create
    @post = @account.linkedin_share_posts.build(post_params.merge(
      platform: "linkedin", tenant_id: @account.tenant_id, status: "draft"
    ))
    if @post.save
      redirect_to posts_path, notice: "LinkedIn 게시물 초안을 저장했습니다.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    reject_locked if @post.publishing_locked?
  end

  def update
    saved = @post.with_lock { @post.update(post_params) unless @post.publishing_locked? }
    return reject_locked if saved.nil?

    if saved
      redirect_to posts_path, notice: "LinkedIn 게시물 초안을 저장했습니다.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def approve
    approved = @post.with_lock do
      @post.update!(approved_at: Time.current, status: "scheduled") unless @post.publishing_locked?
    end
    return reject_locked unless approved

    if @post.scheduled_at <= Time.current
      result = Linkedin::SharePublishing.new.publish_post(@post)
      if result
        flash[result["ok"] == true ? :notice : :alert] = @post.result_message
      else
        flash[:alert] = "게시물 상태가 변경되었습니다. 목록에서 확인하세요."
      end
    else
      time = @post.scheduled_at.in_time_zone(Linkedin::Monitor::TIME_ZONE).strftime("%Y-%m-%d %H:%M")
      flash[:notice] = "예약 시각(#{time})에 게시됩니다."
    end
    redirect_to posts_path, status: :see_other
  end

  def unapprove
    canceled = @post.with_lock do
      @post.update!(approved_at: nil, status: "draft") unless @post.publishing_locked?
    end
    return reject_locked unless canceled

    redirect_to posts_path, notice: "게시 승인을 취소했습니다.", status: :see_other
  end

  private

  def set_linkedin_account
    @account = ProfileAccount.find(params[:profile_account_id])
    return if @account.platform == "linkedin"

    redirect_to pd_profile_account_path(@account), alert: "LinkedIn 계정에서만 게시물을 관리할 수 있습니다.", status: :see_other
  end

  def set_post
    @post = @account.linkedin_share_posts.linkedin_shares.find(params[:id])
  end

  def reject_locked
    redirect_to posts_path, alert: "게시 중이거나 이미 게시된 글입니다.", status: :see_other
  end

  def posts_path
    pd_profile_account_path(@account, anchor: "linkedin-posts")
  end

  def post_params
    permitted = params.require(:sns_scheduled_post).permit(:message, :scheduled_at)
    if permitted.key?(:scheduled_at) || action_name == "create"
      value = permitted[:scheduled_at].presence
      permitted[:scheduled_at] = value ? Time.find_zone!(Linkedin::Monitor::TIME_ZONE).parse(value) : Time.current
    end
    permitted
  rescue ArgumentError
    permitted.merge(scheduled_at: nil)
  end
end
