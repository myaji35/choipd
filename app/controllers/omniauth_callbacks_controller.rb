# Google OAuth2 콜백 핸들러
# - Member.from_omniauth로 회원 찾기/생성
# - 같은 이메일의 AdminUser가 있으면 Devise 세션(admin)도 함께 sign_in
# - 세션에 member_id 저장 → 회원 본인 admin(/:slug/admin) 또는 /admin 대시보드로 리다이렉트
class OmniauthCallbacksController < ApplicationController
  include Devise::Controllers::SignInOut

  skip_before_action :verify_authenticity_token, only: [ :google_oauth2, :failure ]

  def google_oauth2
    auth = request.env["omniauth.auth"]
    unless auth
      redirect_to root_path, alert: "OAuth 응답이 없습니다." and return
    end

    # 1) Member 로그인 (찾거나 신규 생성)
    member = Member.from_omniauth(auth)
    unless member&.persisted?
      Rails.logger.error "[OAuth] Member 생성 실패: #{member&.errors&.full_messages&.join(', ')}"
      redirect_to root_path, alert: "로그인에 실패했습니다. 관리자에게 문의해주세요."
      return
    end

    session[:member_id] = member.id
    member.update(last_sign_in_at: Time.current) rescue nil

    # 2) 같은 이메일의 AdminUser가 있으면 Devise 세션도 함께 생성 (운영자 겸 회원 케이스)
    email = auth.info&.email.to_s.downcase.presence
    admin = AdminUser.find_by("LOWER(email) = ?", email) if email
    if admin
      sign_in(:admin_user, admin)
      Rails.logger.info "[OAuth] AdminUser 세션 함께 생성: #{admin.email} (role=#{admin.role})"
    end

    # 3) 리다이렉트 우선순위
    #    (a) AdminUser role=admin이면 /admin 대시보드로 (운영자가 주로 admin 작업 기대)
    #    (b) Member status=approved면 본인 편집기
    #    (c) pending_approval이면 루트 + 안내
    if admin&.admin?
      redirect_to admin_root_path, notice: "관리자로 로그인되었습니다, #{admin.email}."
    elsif member.status == "approved"
      redirect_to "/#{member.slug}/admin/dashboard", notice: "다시 오신 걸 환영합니다, #{member.name}님."
    else
      redirect_to root_path, notice: "환영합니다, #{member.name}님! 관리자 승인 후 페이지를 편집할 수 있습니다."
    end
  rescue StandardError => e
    Rails.logger.error "[OAuth] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to root_path, alert: "OAuth 처리 중 오류가 발생했습니다."
  end

  # OmniAuth failure 콜백
  def failure
    msg = params[:message].presence || "unknown"
    Rails.logger.warn "[OAuth/failure] #{msg}"
    redirect_to root_path, alert: "로그인이 취소되었거나 실패했습니다 (#{msg})."
  end

  # 회원 OAuth 세션 종료 (AdminUser 세션은 보존)
  def destroy
    session.delete(:member_id)
    redirect_to root_path, notice: "회원 로그아웃되었습니다."
  end
end
