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
    return if warden.user(:admin_user)
    return if session[:member_id] == @member.id

    # 데모 자동 패스 — 비밀번호 미설정 회원만, 본인 PC 가정.
    # 보안 보강: 회원이 비밀번호를 설정하면 자동 패스 즉시 차단됨 (password_digest 검사).
    # 추가 안전장치: 자동 패스 사용 시 안내 flash로 비밀번호 설정 유도.
    if @member.password_digest.blank?
      session[:member_id] = @member.id
      @member.update_columns(last_sign_in_at: Time.current)
      flash.now[:notice] = "데모 모드로 접속했습니다. 보안을 위해 비밀번호를 설정하세요." if flash.now[:notice].blank?
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
