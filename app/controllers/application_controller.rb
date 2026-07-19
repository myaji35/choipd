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

  # Google OAuth 활성 여부 — CLIENT_ID + SECRET 모두 세팅된 경우만 true.
  # 현재 프로덕션 Secret 미설정 + CLIENT_ID가 SocialDoctors-Gmail 소유라 버튼 숨김.
  # 환경변수 채워지면 자동 복원된다.
  def google_oauth_enabled?
    ENV["GOOGLE_OAUTH_CLIENT_ID"].to_s.strip.length > 20 &&
      ENV["GOOGLE_OAUTH_CLIENT_SECRET"].to_s.strip.length > 8
  end
  helper_method :google_oauth_enabled?

  def public_host
    ENV["IMPD_PUBLIC_HOST"].presence || "impd.townin.net"
  end
  helper_method :public_host

  def public_base_url
    scheme = Rails.env.production? ? "https" : "http"
    "#{scheme}://#{public_host}"
  end
  helper_method :public_base_url

  # 공개 프로필을 방문자가 본인인지 판별. 두 경로 중 하나라도 맞으면 owner-view.
  # (1) 회원 세션(session[:member_id])의 회원이 본인
  # (2) Devise admin_user 세션에서 이메일이 회원 이메일과 일치 (admin이 자기 회원 페이지 방문)
  def viewing_as_owner?(member)
    return false if member.blank?
    return true if current_member.present? && current_member.id == member.id
    if defined?(current_admin_user) && current_admin_user.present?
      return true if current_admin_user.email.to_s.downcase == member.email.to_s.downcase
    end
    false
  end
  helper_method :viewing_as_owner?
end
