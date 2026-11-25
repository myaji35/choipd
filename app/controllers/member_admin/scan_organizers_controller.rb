class MemberAdmin::ScanOrganizersController < MemberAdmin::BaseController
  prepend_before_action :require_scan_organizer
  before_action :set_setting

  def show
    @cloud = ScanOrganizer::Clouds.fetch(@setting.cloud_provider)
    @prompt = ScanOrganizer::PromptBuilder.new(member: @member, setting: @setting).build
  end

  def update
    attributes = params.expect(scan_organizer_setting: [
      :cloud_provider, :receipts_sheet_name, :documents_folder_name, :review_folder_name, :run_frequency, :ai_provider, :ai_api_key
    ])
    attributes.delete(:ai_api_key) if attributes[:ai_api_key].blank?
    attributes[:ai_provider] = attributes[:ai_provider].presence if attributes.key?(:ai_provider)

    @setting.assign_attributes(attributes)
    @setting.ai_key_verified_at = nil if @setting.ai_api_key_changed? || @setting.ai_provider_changed?

    if @setting.save
      redirect_to scan_path, notice: "스캔 설정을 저장했습니다.", status: :see_other
    else
      redirect_to scan_path, alert: "스캔 설정을 저장하지 못했습니다. 입력값을 확인해 주세요.", status: :see_other
    end
  end

  def test_ai_key
    if @setting.ai_provider.present? && @setting.ai_api_key.present? &&
        ScanOrganizer.ai_provider_for(@setting).test_connection(@setting.ai_api_key)
      @setting.update!(ai_key_verified_at: Time.current)
      redirect_to scan_path, notice: "AI 키 연결에 성공했습니다.", status: :see_other
    else
      redirect_to scan_path, alert: "AI 키 연결에 실패했습니다. 저장된 제공자와 키를 확인해 주세요.", status: :see_other
    end
  end

  private

  def require_scan_organizer
    raise ActionController::RoutingError, "Not Found" unless ScanOrganizer.enabled?
  end

  def set_setting
    @setting = @member.scan_organizer_setting || @member.build_scan_organizer_setting
  end

  def scan_path
    slug_admin_scan_organizer_path(slug: @member.slug)
  end
end
