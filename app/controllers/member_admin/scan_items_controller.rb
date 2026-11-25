class MemberAdmin::ScanItemsController < MemberAdmin::BaseController
  prepend_before_action :require_scan_organizer

  def resolve
    item = @member.scan_items.find(params[:id])
    setting = @member.scan_organizer_setting
    category = params[:category]
    path = slug_admin_scan_organizer_path(slug: @member.slug)

    unless ScanItem::CATEGORIES.include?(category) && item.status == "needs_review"
      return redirect_to path, alert: "분류할 수 있는 스캔 항목과 분류를 확인해 주세요.", status: :see_other
    end

    cloud = ScanOrganizer.cloud_for(setting) if setting
    ScanOrganizer::Processor.new(member: @member, ai: nil, cloud: cloud).resolve!(item, category)
    if item.status == "processed"
      redirect_to path, notice: "스캔 항목을 정리했습니다.", status: :see_other
    else
      redirect_to path, alert: "스캔 항목을 저장하지 못했습니다. 처리 내역을 확인해 주세요.", status: :see_other
    end
  end

  private

  def require_scan_organizer
    raise ActionController::RoutingError, "Not Found" unless ScanOrganizer.enabled?
  end
end
