class Pd::NaverPeopleTargetsController < Pd::BaseController
  SOURCES = { "naver" => "네이버", "linkedin" => "LinkedIn", "impd" => "imPD" }.freeze

  before_action :set_naver_account
  before_action :set_target, only: [ :show, :edit ]

  def show
    sources = NaverPeople::TargetSources.new(@account)
    @values = @target.values
    @diff = NaverPeople::TargetDiff.new(sources.from("naver"), @values)
    @approval_label = @target.approval_label(@diff)
    @approval_stale = @target.approval_stale?(@diff)
    @cross_check = NaverPeople::CrossCheck.new(@account, sources: sources)
  end

  def edit
    source = params[:source]
    if SOURCES.key?(source)
      @values = NaverPeople::TargetSources.new(@account).from(source)
      flash.now[:notice] = "#{SOURCES.fetch(source)}에서 불러왔습니다. 확인 후 저장하세요."
    elsif @target.persisted?
      @values = @target.values
    else
      @values = NaverPeople::TargetSources.new(@account).from("naver")
    end
  end

  def update
    saved = @account.with_lock do
      set_target
      @target.update(values: target_params)
    end
    if saved
      redirect_to target_path, status: :see_other, notice: "목표 프로필을 저장했습니다."
    else
      @values = @target.values
      render :edit, status: :unprocessable_entity
    end
  end

  def approve
    approved = @account.with_lock do
      set_target
      current = NaverPeople::TargetSources.new(@account).from("naver")
      diff = NaverPeople::TargetDiff.new(current, @target.values)
      next false if diff.items.empty?

      @target.update!(status: "approved", approved_at: Time.current, approved_draft_digest: diff.digest)
    end
    if approved
      redirect_to target_path, status: :see_other, notice: "수정 신청 초안을 승인했습니다. 네이버 제출은 다음 단계에서 대표님 확인 후 진행합니다."
    else
      redirect_to target_path, status: :see_other, alert: "바꿀 항목이 없습니다."
    end
  end

  def unapprove
    @account.with_lock do
      set_target
      if @target.persisted?
        @target.reset_approval
        @target.save!
      end
    end
    redirect_to target_path, status: :see_other
  end

  private

  def set_naver_account
    @account = ProfileAccount.find(params[:profile_account_id])
    return if @account.platform == "naver_people"

    redirect_to pd_profile_account_path(@account), status: :see_other, alert: "네이버 인물정보 계정에서만 목표 프로필을 관리할 수 있습니다."
  end

  def set_target
    @target = @account.naver_people_target || @account.build_naver_people_target(tenant_id: @account.tenant_id)
  end

  def target_path
    pd_profile_account_naver_target_path(@account)
  end

  def target_params
    params.require(:naver_people_target).permit(*NaverPeopleTarget::FIELDS.keys)
  end
end
