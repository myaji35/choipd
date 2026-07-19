class MemberAdmin::SnsAccountsController < MemberAdmin::BaseController
  before_action :set_sns_account, only: [ :update, :destroy ]

  def index
    load_accounts
  end

  def create
    @new_account = @member.sns_accounts.new(sns_account_params)

    if @new_account.save
      redirect_to slug_admin_sns_accounts_path(slug: @member.slug), notice: "SNS 계정을 연결했습니다."
    else
      @sns_accounts = @member.sns_accounts.order(:platform)
      flash.now[:alert] = @new_account.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @sns_account.update(sns_account_update_params)
      redirect_to slug_admin_sns_accounts_path(slug: @member.slug), notice: "SNS 계정을 수정했습니다."
    else
      load_accounts
      flash.now[:alert] = @sns_account.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @sns_account.destroy!
    redirect_to slug_admin_sns_accounts_path(slug: @member.slug), notice: "SNS 계정을 삭제했습니다."
  end

  private

  def load_accounts
    @sns_accounts = @member.sns_accounts.order(:platform)
    @new_account = @member.sns_accounts.new
  end

  def set_sns_account
    @sns_account = @member.sns_accounts.find(params[:id])
  end

  def sns_account_params
    params.require(:sns_account).permit(:platform, :account_name, :access_token, :is_active)
  end

  def sns_account_update_params
    sns_account_params.except(:platform).tap do |permitted|
      permitted.delete(:access_token) if permitted[:access_token].blank?
    end
  end
end
