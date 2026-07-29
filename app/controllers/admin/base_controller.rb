class Admin::BaseController < ApplicationController
  layout "admin"

  # 관리 화면은 최신 브라우저 전제 (ISS-424: 공개 페이지에서는 해제)
  allow_browser versions: :modern

  before_action :authenticate_admin_user!
  before_action :require_admin_role!

  private

  def require_admin_role!
    unless current_admin_user&.admin?
      redirect_to root_path, alert: "접근 권한이 없습니다."
    end
  end
end
