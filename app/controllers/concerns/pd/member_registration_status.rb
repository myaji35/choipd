module Pd::MemberRegistrationStatus
  private

  def member_registration_rows(members)
    members.map do |member|
      channels = member.brands.flat_map(&:brand_channels)
        .select { |channel| MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.key?(channel.platform) }

      {
        member: member,
        account_count: (member.profile_accounts.map(&:platform) & ProfileAccount::PLATFORMS.keys).size,
        channel_count: channels.map(&:platform).uniq.size,
        consent_waiting: channels.count { |channel| !channel.delegated? }
      }
    end
  end

  def registration_todo?(row)
    row.fetch(:account_count) < ProfileAccount::PLATFORMS.size ||
      row.fetch(:channel_count) < MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.size
  end
end
