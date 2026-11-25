class Pd::MembersController < Pd::BaseController
  include Pd::MemberRegistrationStatus

  helper_method :registration_in_progress?

  CHANNEL_PLATFORMS = MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS

  def index
    members = Member.for_tenant.recent.search(params[:q]).includes(:profile_accounts, brands: :brand_channels)
    rows = member_registration_rows(members)
    progress = rows.select { |row| registration_in_progress?(row) }
    todo = rows.select { |row| registration_todo?(row) }
    filtered_rows = {
      "progress" => progress,
      "todo" => todo.sort_by.with_index { |row, index| [registration_in_progress?(row) ? 0 : 1, index] },
      "consent" => rows.select { |row| row.fetch(:consent_waiting).positive? }
    }
    @filter = params[:filter].presence_in(filtered_rows.keys)
    @rows = filtered_rows.fetch(@filter, rows)
    @counts = { all: rows.size, progress: progress.size, todo: todo.size, consent: filtered_rows.fetch("consent").size }
  end

  def show
    @member = Member.for_tenant.find(params[:id])
    @registration_summary = member_registration_rows([@member]).first
    @registration_complete = !registration_todo?(@registration_summary) && @registration_summary.fetch(:consent_waiting).zero?
    @accounts_by_platform = tenant_accounts.where(member_id: @member.id).includes(:naver_people_target)
      .order(:platform, :display_name).group_by(&:platform)
    unlinked_accounts = tenant_accounts.where(member_id: nil, tenant_id: @member.tenant_id)
      .order(:display_name, :id).group_by(&:platform)
    @unlinked_accounts_by_platform = unlinked_accounts.transform_values do |accounts|
      accounts.partition { |account| matching_account?(account) }
    end
    @replacement_candidates = @accounts_by_platform.values.flatten.each_with_object({}) do |account, candidates|
      groups = @unlinked_accounts_by_platform[account.platform]
      next unless groups && replaceable_manual_account?(account)

      candidates[account.id] = groups.map { |group| group.select { |found| found.external_id.present? }.first(5) }
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
