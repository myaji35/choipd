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

  def registration_in_progress?(row)
    (row.fetch(:account_count) + row.fetch(:channel_count)).positive? && registration_todo?(row)
  end

  def replaceable_manual_account?(account)
    account.external_id.blank? &&
      !account.profile_snapshots.exists? &&
      account.naver_people_target.nil? &&
      !account.naver_people_submissions.exists? &&
      !account.linkedin_share_posts.exists? &&
      !account.linkedin_newsletter_drafts.exists? &&
      !account.linkedin_invitation_actions.exists?
  end

  def registration_todo?(row)
    row.fetch(:account_count) < ProfileAccount::PLATFORMS.size ||
      row.fetch(:channel_count) < MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.size
  end
end
