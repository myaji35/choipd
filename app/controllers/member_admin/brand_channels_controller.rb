class MemberAdmin::BrandChannelsController < MemberAdmin::BaseController
  before_action :set_brand_channel

  def edit; end

  def update
    attributes = params.require(:brand_channel).permit(:account_handle, :profile_url, :delegation_consent)
    consent = attributes.delete(:delegation_consent)
    revoked = false

    saved = @brand_channel.with_lock do
      was_delegated = @brand_channel.delegated?
      unless consent.nil?
        @brand_channel.delegation_consent_at =
          ActiveModel::Type::Boolean.new.cast(consent) == true ? (@brand_channel.delegation_consent_at || Time.current) : nil
      end
      revoked = was_delegated && !@brand_channel.delegated?
      if attributes.key?(:account_handle) || attributes.key?(:profile_url)
        BrandChannels::HandleNormalizer.save(@brand_channel, attributes)
      else
        @brand_channel.update(attributes)
      end
    end

    if saved
      message = revoked ? "운영 위탁 동의를 철회했습니다. 공유한 계정 비밀번호를 변경해 주세요." : "채널 정보를 저장했습니다."
      redirect_to slug_admin_brand_path(slug: @member.slug), notice: message
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_member_or_admin
    raise ActiveRecord::RecordNotFound if current_member && current_member != @member

    super
  end

  def set_brand_channel
    raise ActiveRecord::RecordNotFound unless current_member&.id == @member.id

    @brand_channel = BrandChannel.joins(:brand).where(brands: { member_id: current_member.id }).find(params[:id])
  end
end
