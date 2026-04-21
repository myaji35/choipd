class MemberAdmin::BaseController < ApplicationController
  layout "impd_admin"

  before_action :set_member
  before_action :require_member_or_admin

  private

  def set_member
    @member = Member.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError.new("Not Found")
  end

  def require_member_or_admin
    # admin은 모든 회원 접근 / 회원 본인은 자기만
    return if warden.user(:admin_user)
    return if session[:member_id] == @member.id

    # 데모 자동 패스 (Phase 1) — 비밀번호 미설정 회원은 자동 로그인
    if @member.password_digest.blank?
      session[:member_id] = @member.id
      @member.update_columns(last_sign_in_at: Time.current)
      return
    end

    redirect_to login_member_path(slug: @member.slug), alert: "로그인이 필요합니다"
  end

  def warden
    request.env["warden"]
  end

  def current_member
    @current_member ||= Member.find_by(id: session[:member_id])
  end
  helper_method :current_member
end
