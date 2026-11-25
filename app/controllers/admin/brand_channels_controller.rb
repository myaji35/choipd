class Admin::BrandChannelsController < Admin::BaseController
  before_action :set_brand
  before_action :set_brand_channel, only: [ :edit, :update, :destroy ]

  def new
    @brand_channel = @brand.brand_channels.build
  end

  def create
    @brand_channel = @brand.brand_channels.build(tenant_id: @brand.tenant_id)
    if save_with_normalized_handle(brand_channel_params)
      redirect_to admin_brand_path(@brand), notice: "채널을 등록했습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    attributes = brand_channel_params
    saved = if attributes.key?(:account_handle) || attributes.key?(:profile_url)
      save_with_normalized_handle(attributes)
    else
      @brand_channel.update(attributes)
    end

    if saved
      redirect_to admin_brand_path(@brand), notice: "채널을 수정했습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @brand_channel.destroy!
    redirect_to admin_brand_path(@brand), notice: "채널을 삭제했습니다.", status: :see_other
  end

  private

  def save_with_normalized_handle(attributes)
    @brand_channel.platform = attributes[:platform] if attributes.key?(:platform)
    BrandChannels::HandleNormalizer.save(@brand_channel, attributes)
  end

  def set_brand
    @brand = Brand.find(params[:brand_id])
  end

  def set_brand_channel
    @brand_channel = @brand.brand_channels.find(params[:id])
  end

  def brand_channel_params
    params.require(:brand_channel).permit(:platform, :account_handle, :profile_url, :connection_method,
      :credential_ref, :ego_server_name, :sns_account_id, :profile_account_id, :session_status, :last_checked_at,
      :last_error, :posting_cadence, :notes)
  end
end
