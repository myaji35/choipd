class MemberAdmin::ChannelsController < MemberAdmin::BaseController
  include MemberAdmin::ChannelOverview

  def index
    @channel_overview = build_channel_overview(detail: true)
    @own_session = current_member&.id == @member.id
  end
end
