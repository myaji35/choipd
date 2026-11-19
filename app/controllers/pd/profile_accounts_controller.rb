class Pd::ProfileAccountsController < Pd::BaseController
  before_action :set_account, only: [ :show, :edit, :update, :destroy ]

  def index
    @accounts = ProfileAccount.order(:platform, :display_name).group_by(&:platform)
    @ego_available = EgoProfile::Runner.available?
  end

  def show
    @snapshots = @account.profile_snapshots.recent.limit(20)
    @latest_snapshot = @snapshots.first
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

  def set_account
    @account = ProfileAccount.find(params[:id])
  end

  def account_params
    params.require(:profile_account).permit(:platform, :login_id, :external_id, :display_name, :headline, :profile_url, :notes, :is_active)
  end
end
