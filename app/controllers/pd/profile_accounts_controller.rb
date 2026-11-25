class Pd::ProfileAccountsController < Pd::BaseController
  include Pd::MemberRegistrationStatus

  before_action :set_account, only: [ :show, :edit, :update, :destroy, :invitation_action, :search_queries ]

  helper_method :more_registrations?

  def index
    @accounts = tenant_accounts.includes(:member).order(:platform, :display_name).group_by(&:platform)
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
    if @account.platform == "naver_people"
      target = @account.naver_people_target
      if target&.status == "approved"
        current = NaverPeople::TargetSources.new(@account).values_for("naver")
        diff = NaverPeople::TargetDiff.new(current, target.values)
      end
      @naver_target_status = target&.approval_label(diff) || "초안"
    end
    if @account.platform == "linkedin"
      @linkedin_monitor = Linkedin::Monitor.new(@snapshots)
      @linkedin_posts = @account.linkedin_share_posts.linkedin_shares.recent.order(id: :desc).limit(20)
      @linkedin_newsletter_drafts = @account.linkedin_newsletter_drafts.order(updated_at: :desc, id: :desc)
      return unless @latest_snapshot

      @linkedin_invitation_actions = @account.linkedin_invitation_actions.order(id: :asc).index_by(&:invitation_key)
      accounts = ProfileAccount.active.for_platform("naver_people").where(tenant_id: @account.tenant_id)
      accounts = accounts.where(member_id: @account.member_id) if @account.member_id
      @naver_snapshot = ProfileSnapshot.where(profile_account: accounts).recent.first
    end
  end

  def new
    @lock_member = params[:member_id].present?
    @lock_platform = params[:platform].present?
    platform = params[:platform].presence_in(ProfileAccount::PLATFORMS.keys)
    @member = Member.for_tenant.find_by(id: params[:member_id])
    @account = ProfileAccount.new({ member: @member, platform: platform }.compact)
    @account.display_name = @member.name if @member
  end

  def create
    @lock_member = params[:lock_member] == "1"
    @lock_platform = params[:lock_platform] == "1"
    @account = tenant_accounts.new
    assign_account_attributes
    if @account.errors.empty? && @account.save
      if @member
        redirect_after_registration
      else
        redirect_to pd_profile_account_path(@account), notice: "인물정보 계정이 추가되었습니다."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @member = Member.for_tenant.find_by(id: @account.member_id)
  end

  def update
    return link_account if params[:link] == "1" || params[:return_to] == "member"

    assign_account_attributes
    if @account.errors.empty? && @account.save
      redirect_to pd_profile_account_path(@account), notice: "인물정보 계정이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @account.destroy!
    redirect_to pd_profile_accounts_path, notice: "인물정보 계정이 삭제되었습니다."
  end

  def search_queries
    return head :unprocessable_entity unless @account.platform == "naver_people"
    return head :unprocessable_entity unless params[:search_queries].is_a?(String)

    @account.update!(search_query_list: params[:search_queries].lines)
    redirect_to pd_profile_account_path(@account), status: :see_other, notice: "검색어를 저장했습니다. 다음 점검부터 적용됩니다."
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

  def redirect_after_registration
    if params[:next] == "1"
      notice = "#{@account.platform_label} 계정을 등록했습니다."
      if (platform = remaining_account_platforms.first)
        return redirect_to new_pd_profile_account_path(member_id: @member.id, platform: platform),
          notice: "#{notice} 이어서 #{ProfileAccount::PLATFORMS.fetch(platform)} 계정을 등록하세요."
      end
      if (platform = remaining_channel_platforms.first)
        return redirect_to new_pd_member_channel_path(@member, platform: platform),
          notice: "#{notice} 이어서 #{MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.fetch(platform)} 채널을 등록하세요."
      end
    end

    redirect_to pd_member_path(@member, anchor: "accounts"),
      notice: "#{@account.platform_label} 계정을 등록했습니다. 회원 대시보드 '내 프로필 관리 현황'에 바로 보입니다."
  end

  def more_registrations?
    (remaining_account_platforms - [@account.platform]).any? || remaining_channel_platforms.any?
  end

  def remaining_account_platforms
    ProfileAccount::PLATFORMS.keys - @member.profile_accounts.distinct.pluck(:platform)
  end

  def remaining_channel_platforms
    platforms = MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.keys
    platforms - BrandChannel.joins(:brand).where(brands: { member_id: @member.id }, platform: platforms).distinct.pluck(:platform)
  end

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
    @account = tenant_accounts.find(params[:id])
  end

  def assign_account_attributes
    attributes = account_params
    @account.assign_attributes(attributes.except(:member_id))
    member_id = attributes.fetch(:member_id, @account.member_id)
    @member = Member.for_tenant.find_by(id: member_id) if member_id.present?
    return unless attributes.key?(:member_id)

    @account.member = @member
    @account.errors.add(:base, "회원을 찾을 수 없어요.") if member_id.present? && @member.nil?
  end

  def link_account
    @member = Member.for_tenant.find_by(id: account_params[:member_id].presence)
    unless @member
      @account.errors.add(:base, "회원을 찾을 수 없어요.")
      return render :edit, status: :unprocessable_entity
    end

    return replace_manual_account if params.key?(:replace_id)

    linked = link_unassigned_account

    if linked == 1
      flash[:notice] = "#{@account.platform_label} 계정을 #{@member.name} 회원에 연결했습니다."
    else
      flash[:alert] = "이미 다른 회원에게 연결된 계정이에요."
    end
    redirect_to pd_member_path(@member, anchor: "accounts"), status: :see_other
  end

  def replace_manual_account
    alert = "이 계정에는 이미 점검 기록이나 작성한 내용이 있어 바꿀 수 없어요."
    ProfileAccount.transaction(requires_new: true) do
      @account.lock!
      raise ActiveRecord::Rollback if @account.external_id.blank?

      manual = tenant_accounts.where(member_id: @member.id, platform: @account.platform).lock.find_by(id: params[:replace_id])
      unless manual && replaceable_manual_account?(manual)
        raise ActiveRecord::Rollback
      end

      unless link_unassigned_account == 1
        alert = "이미 다른 회원에게 연결된 계정이에요."
        raise ActiveRecord::Rollback
      end

      @account.reload
      @account.login_id = manual.login_id if @account.login_id.blank?
      @account.profile_url = manual.profile_url if @account.profile_url.blank?
      if manual.notes.present?
        @account.notes = [@account.notes.presence, manual.notes].compact.join("\n")
      end
      @account.save!
      manual.destroy!
      alert = nil
    end

    if alert
      flash[:alert] = alert
    else
      flash[:notice] = "#{@account.platform_label} 계정을 점검이 찾은 계정으로 바꿨습니다. 손으로 등록한 계정은 지우고 메모는 옮겼습니다."
    end
    redirect_to pd_member_path(@member, anchor: "accounts"), status: :see_other
  end

  def link_unassigned_account
    tenant_accounts.where(id: @account.id, member_id: nil)
      .update_all(member_id: @member.id, updated_at: Time.current)
  end

  def account_params
    params.require(:profile_account).permit(:member_id, :platform, :login_id, :external_id, :display_name, :headline, :profile_url, :notes, :is_active)
  end
end
