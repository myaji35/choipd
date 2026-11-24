class Pd::ProfileAccountNewsletterDraftsController < Pd::BaseController
  before_action :set_linkedin_account
  before_action :set_draft, except: :create

  def create
    @draft = @account.linkedin_newsletter_drafts.build(draft_params.merge(tenant_id: @account.tenant_id))
    if @draft.save
      redirect_to drafts_path, notice: "뉴스레터 초안을 저장했습니다.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    reject_locked if @draft.publishing_locked?
  end

  def update
    saved = @draft.with_lock { @draft.update(draft_params) unless @draft.publishing_locked? }
    return reject_locked if saved.nil?

    if saved
      redirect_to drafts_path, notice: "뉴스레터 초안을 저장했습니다.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    archived = @draft.with_lock do
      @draft.update!(status: "archived", archived_at: Time.current, approved_at: nil) unless @draft.publishing_locked?
    end
    return reject_locked unless archived

    redirect_to drafts_path, status: :see_other
  end

  def restore
    restored = @draft.with_lock do
      @draft.update!(status: "draft", archived_at: nil, approved_at: nil) if @draft.status == "archived"
    end
    return reject_locked unless restored

    redirect_to drafts_path, status: :see_other
  end

  def publish
    approved = @draft.with_lock do
      @draft.update!(approved_at: Time.current) if !@draft.publishing_locked? && @draft.status.in?(%w[draft failed])
    end
    return reject_locked unless approved

    result = Linkedin::SharePublishing.new.publish_newsletter(@draft)
    if result
      flash[result["ok"] == true ? :notice : :alert] = @draft.result_message
    else
      flash[:alert] = "초안 상태가 변경되었습니다. 목록에서 확인하세요."
    end
    redirect_to drafts_path, status: :see_other
  end

  private

  def reject_locked
    redirect_to drafts_path, alert: "발행 중이거나 이미 발행되었거나 보관된 글입니다.", status: :see_other
  end

  def set_linkedin_account
    @account = ProfileAccount.find(params[:profile_account_id])
    return if @account.platform == "linkedin"

    redirect_to pd_profile_account_path(@account), alert: "LinkedIn 계정에서만 뉴스레터 초안을 관리할 수 있습니다.", status: :see_other
  end

  def set_draft
    @draft = @account.linkedin_newsletter_drafts.find(params[:id])
  end

  def drafts_path
    pd_profile_account_path(@account, anchor: "newsletter-drafts")
  end

  def draft_params
    params.require(:linkedin_newsletter_draft).permit(:newsletter_name, :title, :body)
  end
end
