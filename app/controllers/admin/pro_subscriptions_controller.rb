class Admin::ProSubscriptionsController < Admin::BaseController
  before_action :set_subscription, only: [ :show, :activate, :cancel ]

  def index
    @subscription = ProSubscription.for_owner(current_admin_user.id).first
  end

  def show; end

  def start_trial
    sub = ProSubscription.start_trial!(owner_id: current_admin_user.id)
    redirect_to admin_pro_subscription_path(sub), notice: "14일 무료 체험 시작"
  end

  def activate
    @subscription.activate!(payment_method: "stub")
    redirect_to admin_pro_subscription_path(@subscription), notice: "Pro 구독 활성화 (stub 결제)"
  end

  def cancel
    @subscription.cancel!
    redirect_to admin_pro_subscriptions_path, notice: "구독 취소됨"
  end

  private

  def set_subscription
    @subscription = ProSubscription.for_owner(current_admin_user.id).find(params[:id])
  end
end
