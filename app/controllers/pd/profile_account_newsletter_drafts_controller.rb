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

  def edit; end

  def update
    if @draft.update(draft_params)
      redirect_to drafts_path, notice: "뉴스레터 초안을 저장했습니다.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    @draft.with_lock { @draft.update!(status: "archived", archived_at: Time.current) unless @draft.status == "archived" }
    redirect_to drafts_path, status: :see_other
  end

  def restore
    @draft.with_lock { @draft.update!(status: "draft", archived_at: nil) }
    redirect_to drafts_path, status: :see_other
  end

  private

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
