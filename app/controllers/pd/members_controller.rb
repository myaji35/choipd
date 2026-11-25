class Pd::MembersController < Pd::BaseController
  include Pd::MemberRegistrationStatus

  CHANNEL_PLATFORMS = MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS

  def index
    members = Member.for_tenant.recent.search(params[:q]).includes(:profile_accounts, brands: :brand_channels)
    rows = member_registration_rows(members)
    filtered_rows = {
      "todo" => rows.select { |row| registration_todo?(row) },
      "consent" => rows.select { |row| row.fetch(:consent_waiting).positive? }
    }
    @filter = params[:filter].presence_in(filtered_rows.keys)
    @rows = filtered_rows.fetch(@filter, rows)
    @counts = { all: rows.size, todo: filtered_rows.fetch("todo").size, consent: filtered_rows.fetch("consent").size }
  end

  def show
    @member = Member.for_tenant.find(params[:id])
    @accounts_by_platform = @member.profile_accounts.order(:platform, :display_name).group_by(&:platform)
    unlinked_accounts = ProfileAccount.where(member_id: nil, tenant_id: @member.tenant_id)
      .order(:display_name, :id).group_by(&:platform)
    @unlinked_accounts_by_platform = unlinked_accounts.transform_values do |accounts|
      accounts.partition { |account| matching_account?(account) }
    end
    @channels_by_platform = BrandChannel.joins(:brand)
      .where(brands: { member_id: @member.id }, platform: CHANNEL_PLATFORMS.keys)
      .order(brands: { personal: :desc }).order(:id)
      .group_by(&:platform)
  end

  private

  def matching_account?(account)
    account_name = account.display_name.to_s.downcase.gsub(/[^[:alnum:]]/, "")
    member_name = @member.name.to_s.downcase.gsub(/[^[:alnum:]]/, "")
    if account_name.length >= 2 && member_name.length >= 2 &&
        (account_name.include?(member_name) || member_name.include?(account_name))
      return true
    end

    email = @member.email.to_s.downcase
    account.login_id.present? && [ email, email.split("@", 2).first ].include?(account.login_id.downcase)
  end
end
