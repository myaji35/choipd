class ApplicationController < ActionController::Base
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_root_path
    else
      pd_root_path
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    new_admin_user_session_path
  end

  # ── 회원(Member) 세션 공용 헬퍼 ──────────────────
  # MemberSessionsController / MemberAuthController / OmniauthCallbacksController
  # 모두 session[:member_id] 로 회원 세션을 기록한다. 어디서든 읽을 수 있도록
  # ApplicationController 에 올려 helper_method 로 뷰 공개.
  def current_member
    return @current_member if defined?(@current_member)
    @current_member = Member.find_by(id: session[:member_id])
  end
  helper_method :current_member

  def member_signed_in?
    current_member.present?
  end
  helper_method :member_signed_in?
end
