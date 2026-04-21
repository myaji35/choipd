class Admin::IntegrationsController < Admin::BaseController
  before_action :set_integration, only: [ :show, :edit, :update, :destroy, :test ]

  def index
    @integrations = Integration.for_tenant.order(:provider, :name)
  end

  def show; end

  def new
    @integration = Integration.new(type_name: "messaging", provider: "slack")
  end

  def create
    @integration = Integration.new(integration_params.merge(
      tenant_id: 1, created_by: current_admin_user.email,
      credentials: (params[:credentials_json].presence || "{}")
    ))
    if @integration.save
      redirect_to admin_integration_path(@integration), notice: "연동 추가됨"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @integration.update!(integration_params)
    redirect_to admin_integration_path(@integration)
  end

  def destroy
    @integration.destroy
    redirect_to admin_integrations_path
  end

  def test
    result = @integration.test_connection!
    redirect_to admin_integration_path(@integration), notice: result[:message]
  end

  private

  def set_integration
    @integration = Integration.for_tenant.find(params[:id])
  end

  def integration_params
    params.permit(:name, :type_name, :provider, :is_enabled, :webhook_url, :error_message)
  end
end
