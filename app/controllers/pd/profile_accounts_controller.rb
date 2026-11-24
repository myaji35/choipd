class Pd::ProfileAccountsController < Pd::BaseController
  before_action :set_account, only: [ :show, :edit, :update, :destroy, :invitation_action ]

  def index
    @accounts = ProfileAccount.order(:platform, :display_name).group_by(&:platform)
    @ego_available = EgoProfile::Runner.available?
  end

  def weekly_report
    @today = ProfileAccounts::WeeklyReport.today
    @earliest_week_end = Date.new(2020, 1, 1)
    week_end = report_week_end(params[:week_end])
    @report = ProfileAccounts::WeeklyReport.new(week_end: week_end).to_h
  end

  def show
    @snapshots = @account.profile_snapshots.recent.limit(@account.platform == "linkedin" ? 60 : 20).to_a
    @latest_snapshot = @snapshots.first
    if @account.platform == "linkedin"
      @linkedin_monitor = Linkedin::Monitor.new(@snapshots)
      @linkedin_newsletter_drafts = @account.linkedin_newsletter_drafts.order(updated_at: :desc, id: :desc)
      return unless @latest_snapshot

      @linkedin_invitation_actions = @account.linkedin_invitation_actions.order(id: :asc).index_by(&:invitation_key)
      accounts = ProfileAccount.active.for_platform("naver_people").where(tenant_id: @account.tenant_id)
      accounts = accounts.where(member_id: @account.member_id) if @account.member_id
      @naver_snapshot = ProfileSnapshot.where(profile_account: accounts).recent.first
    end
  end

  def new
    @account = ProfileAccount.new
  end

  def create
    @account = ProfileAccount.new(account_params)
    if @account.save
      redirect_to pd_profile_account_path(@account), notice: "인물정보 계정이 추가되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @account.update(account_params)
      redirect_to pd_profile_account_path(@account), notice: "인물정보 계정이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @account.destroy!
    redirect_to pd_profile_accounts_path, notice: "인물정보 계정이 삭제되었습니다."
  end

  def invitation_action
    decision = params[:decision]
    unless LinkedinInvitationAction::ACTIONS.include?(decision)
      return redirect_to pd_profile_account_path(@account), alert: "올바르지 않은 승인입니다.", status: :see_other
    end

    approval = @account.with_lock { approve_invitation(params[:invitation_key], decision) }
    if approval.is_a?(String)
      return redirect_to pd_profile_account_path(@account), alert: approval, status: :see_other
    end

    result = EgoProfile::InvitationExecutor.new.call(approval)
    success = result["ok"] == true
    message = if success
      decision == "accept" ? "LinkedIn 신청을 수락했습니다." : "LinkedIn 신청을 건너뛰었습니다."
    else
      result["reason"].presence || "LinkedIn 신청 처리 결과를 확인할 수 없습니다."
    end
    approval.update!(status: success ? "done" : "failed", executed_at: Time.current, result_message: message)
    flash[success ? :notice : :alert] = message
    redirect_to pd_profile_account_path(@account), status: :see_other
  end

  def check
    unless EgoProfile::Runner.available?
      return redirect_to pd_profile_accounts_path, alert: "ego 브라우저가 설치된 Mac에서만 점검할 수 있습니다."
    end
    platforms = params[:platform].presence ? [ params[:platform] ] : ProfileAccount::PLATFORMS.keys
    unless platforms.all? { |platform| ProfileAccount::PLATFORMS.key?(platform) }
      return redirect_to pd_profile_accounts_path, alert: "알 수 없는 플랫폼입니다."
    end
    checker = EgoProfile::Checker.new
    redirect_to pd_profile_accounts_path, notice: platforms.map { |platform| checker.call(platform).summary }.join(" / ")
  end

  private

  def report_week_end(value)
    return @today unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    date = Date.iso8601(value)
    (@earliest_week_end..@today).cover?(date) ? date : @today
  rescue Date::Error
    @today
  end

  def approve_invitation(key, decision)
    return "목록에 없는 신청입니다" unless @account.platform == "linkedin"

    monitor = Linkedin::Monitor.new(@account.profile_snapshots.recent.limit(60))
    invitation = monitor.latest_network[:invitations].find { |entry| entry[:key] == key }
    return "목록에 없는 신청입니다" unless invitation

    actions = @account.linkedin_invitation_actions.where(invitation_key: key)
    return "이미 처리한 신청입니다." if actions.exists?(status: "done")
    return "이미 실행을 승인한 신청입니다." if actions.exists?(status: "approved")

    actions.create!(
      **invitation.slice(:kind, :name, :headline),
      tenant_id: @account.tenant_id, action: decision, status: "approved", approved_at: Time.current
    )
  end

  def set_account
    @account = ProfileAccount.find(params[:id])
  end

  def account_params
    params.require(:profile_account).permit(:platform, :login_id, :external_id, :display_name, :headline, :profile_url, :notes, :is_active)
  end
end
