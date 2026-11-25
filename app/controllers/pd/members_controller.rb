class Pd::MembersController < Pd::BaseController
  CHANNEL_PLATFORMS = MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS

  def index
    @members = Member.for_tenant.recent.search(params[:q]).includes(:profile_accounts, brands: :brand_channels)
  end

  def show
    @member = Member.for_tenant.find(params[:id])
    @accounts_by_platform = @member.profile_accounts.order(:platform, :display_name).group_by(&:platform)
    @unlinked_accounts_by_platform = ProfileAccount.where(member_id: nil, tenant_id: @member.tenant_id)
      .order(:display_name, :id).group_by(&:platform)
    @channels_by_platform = BrandChannel.joins(:brand)
      .where(brands: { member_id: @member.id }, platform: CHANNEL_PLATFORMS.keys)
      .order(brands: { personal: :desc }).order(:id)
      .group_by(&:platform)
  end
end
