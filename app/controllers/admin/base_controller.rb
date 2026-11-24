class Admin::BaseController < ApplicationController
  layout "admin"

  # 관리 화면은 최신 브라우저 전제 (ISS-424: 공개 페이지에서는 해제)
  allow_browser versions: :modern

  before_action :authenticate_admin_user!
  before_action :require_admin_role!

  private

  def require_admin_role!
    return if current_admin_user&.admin?

    if current_admin_user&.pd?
      redirect_to pd_root_path, alert: "PD 계정은 운영자 화면에 들어갈 수 없어 PD 대시보드로 이동했습니다."
    else
      redirect_to root_path, alert: "접근 권한이 없습니다."
    end
  end
end
