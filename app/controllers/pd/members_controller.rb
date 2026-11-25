class Pd::MembersController < Pd::BaseController
  include Pd::MemberRegistrationStatus
  include MemberAdmin::ChannelOverview

  CHANNEL_PLATFORMS = MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS

  helper_method :registration_in_progress?

  def index
    members = Member.for_tenant.recent.search(params[:q]).includes(:profile_accounts, brands: :brand_channels)
    rows = member_registration_rows(members)
    progress = rows.select { |row| registration_in_progress?(row) }
    todo = rows.select { |row| registration_todo?(row) }
    filtered_rows = {
      "progress" => progress,
      "todo" => todo.sort_by.with_index { |row, index| [registration_in_progress?(row) ? 0 : 1, index] },
      "consent" => rows.select { |row| row.fetch(:consent_waiting).positive? },
      "connection" => rows.select { |row| row.fetch(:connection_todo).positive? }
    }
    @filter = params[:filter].presence_in(filtered_rows.keys)
    @rows = filtered_rows.fetch(@filter, rows)
    @counts = { all: rows.size, progress: progress.size, todo: todo.size, consent: filtered_rows.fetch("consent").size,
      connection: filtered_rows.fetch("connection").size }
  end

  def show
    @member = Member.for_tenant.find(params[:id])
    @registration_summary = member_registration_rows([@member]).first
    @registration_complete = !registration_todo?(@registration_summary) && @registration_summary.fetch(:consent_waiting).zero?
    @accounts_by_platform = tenant_accounts.where(member_id: @member.id).includes(:naver_people_target)
      .order(:platform, :display_name).group_by(&:platform)
    linked_accounts = @accounts_by_platform.values.flatten
    @matching_names = [@member.name, *linked_accounts.map(&:display_name)]
      .map { |name| normalized_account_name(name) }.select { |name| name.length >= 2 }.uniq
    email = @member.email.to_s.downcase
    @matching_login_ids = [email, email.split("@", 2).first, *linked_accounts.map(&:login_id)]
      .filter_map { |login_id| login_id.presence&.downcase }.uniq

    unlinked_accounts = tenant_accounts.where(member_id: nil, tenant_id: @member.tenant_id)
      .order(:display_name, :id).group_by(&:platform)
    @unlinked_accounts_by_platform = unlinked_accounts.transform_values do |accounts|
      accounts.partition { |account| matching_account?(account) }
    end
    @replacement_candidates = {}
    @extra_found_accounts = {}
    @accounts_by_platform.each do |platform, accounts|
      groups = @unlinked_accounts_by_platform[platform]
      next unless groups

      candidates = groups.map { |group| group.select { |found| found.external_id.present? }.first(5) }
      replaceable_accounts = accounts.select { |account| replaceable_manual_account?(account) }
      if replaceable_accounts.empty?
        @extra_found_accounts[platform] = candidates.first if candidates.first.any?
      else
        replaceable_accounts.each { |account| @replacement_candidates[account.id] = candidates }
      end
    end
    @channel_overview_by_platform = build_channel_overview.select { |item| item[:channel] }
      .group_by { |item| item[:platform] }
  end

  private

  def matching_account?(account)
    account_name = normalized_account_name(account.display_name)
    if account_name.length >= 2 && @matching_names.any? { |name| account_name.include?(name) || name.include?(account_name) }
      return true
    end

    account.login_id.present? && @matching_login_ids.include?(account.login_id.downcase)
  end

  def normalized_account_name(name)
    name.to_s.downcase.gsub(/[^[:alnum:]]/, "")
  end
end
