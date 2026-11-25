class Pd::MemberChannelsController < Pd::BaseController
  CHANNEL_PLATFORMS = MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS

  before_action :set_member
  before_action :set_channel, only: [ :edit, :update ]

  helper_method :remaining_channel_platforms

  def new
    @lock_platform = CHANNEL_PLATFORMS.key?(params[:platform])
    @brand_channel = BrandChannel.new(platform: params[:platform].presence_in(CHANNEL_PLATFORMS.keys))
  end

  def create
    attributes = create_params
    @brand_channel = BrandChannel.new(attributes)
    @lock_platform = params[:lock_platform] == "1" && CHANNEL_PLATFORMS.key?(@brand_channel.platform)
    unless CHANNEL_PLATFORMS.key?(@brand_channel.platform)
      @brand_channel.errors.add(:platform, "채널 종류를 선택해 주세요.")
      return render :new, status: :unprocessable_entity
    end

    existing_channel = nil
    @member.with_lock(requires_new: true) do
      existing_channel = member_channels.where(platform: @brand_channel.platform)
        .order(brands: { personal: :desc }).order(:id).first
      unless existing_channel
        brand = @member.ensure_personal_brand!
        @brand_channel = brand.brand_channels.build(attributes)
        raise ActiveRecord::Rollback unless save_channel(attributes)
      end
    end

    if existing_channel
      redirect_to edit_pd_member_channel_path(@member, existing_channel), notice: "이미 등록된 채널이 있어 수정 화면으로 이동했습니다."
    elsif @brand_channel.persisted?
      redirect_after_create
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    saved = @brand_channel.with_lock { save_channel(update_params) }
    if saved
      redirect_to pd_member_path(@member, anchor: "channels"), notice: "#{channel_label} 채널을 수정했습니다.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def normalized_attributes(attributes)
    platform = @brand_channel.platform
    handle = attributes.fetch(:account_handle, @brand_channel.account_handle)
    profile_url = attributes.fetch(:profile_url, @brand_channel.profile_url).to_s.strip
    if @brand_channel.persisted? && profile_url == BrandChannels::HandleNormalizer.canonical_url(platform, @brand_channel.account_handle)
      profile_url = ""
    end

    normalized = BrandChannels::HandleNormalizer.call(platform: platform, handle: handle, profile_url: profile_url)
    attributes.merge(account_handle: normalized.fetch(:handle), profile_url: normalized.fetch(:profile_url))
  end

  def save_channel(attributes)
    submitted_url = attributes.fetch(:profile_url, @brand_channel.profile_url)
    @brand_channel.assign_attributes(normalized_attributes(attributes))
    @brand_channel.validate
    handle = @brand_channel.account_handle
    if handle.blank?
      @brand_channel.errors.add(:account_handle, "계정 이름을 적어 주세요. 채널 주소만 붙여 넣어도 됩니다.")
    elsif handle.match?(%r{[[:space:]/@]})
      @brand_channel.errors.add(:account_handle, "계정 이름에는 빈칸이나 주소를 넣을 수 없습니다. 예: gagahoho_kang")
    end
    return true if @brand_channel.errors.empty? && @brand_channel.save(validate: false)

    @brand_channel.profile_url = submitted_url
    false
  end

  def redirect_after_create
    next_platform = remaining_channel_platforms.first if params[:next] == "1"
    if next_platform
      next_label = CHANNEL_PLATFORMS.fetch(next_platform)
      redirect_to new_pd_member_channel_path(@member, platform: next_platform),
        notice: "#{channel_label} 채널을 등록했습니다. 이어서 #{next_label}을 등록하세요."
    else
      redirect_to pd_member_path(@member, anchor: "channels"), notice: "#{channel_label} 채널을 등록했습니다. 회원 화면에 바로 보입니다."
    end
  end

  def remaining_channel_platforms
    CHANNEL_PLATFORMS.keys - member_channels.distinct.pluck(:platform)
  end

  def set_member
    @member = Member.for_tenant.find(params[:member_id])
  end

  def set_channel
    @brand_channel = member_channels.find(params[:id])
  end

  def member_channels
    BrandChannel.joins(:brand).where(brands: { member_id: @member.id }, platform: CHANNEL_PLATFORMS.keys)
  end

  def channel_label
    CHANNEL_PLATFORMS.fetch(@brand_channel.platform)
  end

  def create_params
    params.require(:brand_channel).permit(:platform, :account_handle, :profile_url, :notes)
  end

  def update_params
    params.require(:brand_channel).permit(:account_handle, :profile_url, :notes)
  end
end
