class Admin::WebhooksController < Admin::BaseController
  before_action :set_webhook, only: [ :show, :edit, :update, :destroy, :test ]

  def index
    @webhooks = Webhook.for_tenant.order(:name)
  end

  def show
    @logs = @webhook.webhook_logs.order(created_at: :desc).limit(50)
  end

  def new
    @webhook = Webhook.new(events: '["distributor.created","payment.completed"]')
  end

  def create
    events_arr = (params[:events_text] || "").split(",").map(&:strip).reject(&:blank?)
    @webhook = Webhook.new(
      tenant_id: 1,
      name: params[:name],
      url: params[:url],
      events: events_arr.to_json,
      secret: params[:secret].presence || SecureRandom.hex(32),
      is_active: true,
      created_by: current_admin_user.email
    )
    if @webhook.save
      redirect_to admin_webhook_path(@webhook), notice: "웹훅 추가됨"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @webhook.update!(params.permit(:name, :url, :is_active))
    redirect_to admin_webhook_path(@webhook)
  end

  def destroy
    @webhook.destroy
    redirect_to admin_webhooks_path
  end

  def test
    @webhook.dispatch!(event: @webhook.events_list.first || "test", payload: { test: true, at: Time.current.iso8601 })
    redirect_to admin_webhook_path(@webhook), notice: "테스트 송출 완료"
  rescue StandardError => e
    redirect_to admin_webhook_path(@webhook), alert: "송출 실패: #{e.message}"
  end

  private

  def set_webhook
    @webhook = Webhook.for_tenant.find(params[:id])
  end
end
