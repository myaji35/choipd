class MemberAdmin::BaseController < ApplicationController
  layout "impd_admin"

  before_action :set_member
  before_action :require_member_or_admin

  private

  def normalize_web_address(value)
    return value unless value.is_a?(String)

    address = value.strip
    return address if address.empty? || address.match?(/\A[a-z][a-z0-9+.-]*:|[[:space:]]/i)

    "https://#{address}"
  end

  def set_member
    @member = Member.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError.new("Not Found")
  end

  def require_member_or_admin
    return if warden.user(:admin_user)
    if session[:member_id] == @member.id && !@member.can_sign_in?
      session.delete(:member_id)
      return reject_unapproved_member(@member)
    end

    return if current_member&.id == @member.id

    redirect_to login_member_path(slug: @member.slug), alert: "로그인이 필요합니다"
  end

  def warden
    request.env["warden"]
  end

  def impersonating_admin_user
    warden.user(:admin_user) if @member && current_member&.id != @member.id
  end
  helper_method :impersonating_admin_user
end
