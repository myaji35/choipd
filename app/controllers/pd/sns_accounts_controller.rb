class Pd::SnsAccountsController < Pd::BaseController
  before_action :set_sns_account, only: [ :edit, :update, :destroy ]

  def index
    @sns_accounts = SnsAccount.all.order(:platform)
  end

  def new
    @sns_account = SnsAccount.new
  end

  def create
    @sns_account = SnsAccount.new(sns_account_params)
    if @sns_account.save
      redirect_to pd_sns_accounts_path, notice: "SNS 계정이 연결되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @sns_account.update(sns_account_params)
      redirect_to pd_sns_accounts_path, notice: "SNS 계정이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @sns_account.destroy
    redirect_to pd_sns_accounts_path, notice: "SNS 계정이 해제되었습니다."
  end

  private

  def set_sns_account
    @sns_account = SnsAccount.find(params[:id])
  end

  def sns_account_params
    params.require(:sns_account).permit(:platform, :account_name, :access_token_encrypted, :is_active)
  end
end
