class Pd::BaseController < ApplicationController
  layout "pd"
  before_action :authenticate_admin_user!
  before_action :require_pd_role!

  private

  def require_pd_role!
    unless current_admin_user&.pd? || current_admin_user&.admin?
      redirect_to root_path, alert: "접근 권한이 없습니다."
    end
  end
end
