# 회원(Member) 전용 로그인 페이지.
# /auth/login — 이메일+비밀번호 또는 Google OAuth
# 이메일: 이 컨트롤러의 #create 가 직접 처리
# OAuth:  POST /auth/google_oauth2 → OmniauthCallbacksController
class MemberAuthController < ApplicationController
  layout "application"
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
    if redirect_if_signed_in
      nil
    end
    # flash alert/notice 그대로 표시
  end

  # 이메일/비밀번호 로그인. Member 전체에서 이메일 매칭 → password_digest 검증.
  # password_digest 없으면(= OAuth-only 회원) Google로 유도.
  def create
    email = params[:email].to_s.strip.downcase
    password = params[:password].to_s

    if email.blank? || password.blank?
      redirect_to member_login_path, alert: "이메일과 비밀번호를 입력해 주세요." and return
    end

    member = Member.where("LOWER(email) = ?", email).first

    unless member && member.withdrawn_at.blank?
      # 보안상 "이메일이 없다"고 직접 말하지 않는다. 동일한 메시지로 통일.
      redirect_to member_login_path, alert: "이메일 또는 비밀번호가 일치하지 않습니다." and return
    end

    if member.password_digest.blank?
      redirect_to member_login_path, alert: oauth_only_login_alert and return
    end

    unless member.authenticate(password)
      redirect_to member_login_path, alert: "이메일 또는 비밀번호가 일치하지 않습니다." and return
    end

    return if reject_unapproved_member(member)

    session[:member_id] = member.id
    member.update(last_sign_in_at: Time.current) if member.respond_to?(:last_sign_in_at)
    redirect_to "/#{member.slug}", notice: "환영합니다, #{member.name}님"
  end

  private

  def redirect_if_signed_in
    member = current_member
    return false unless member

    redirect_to "/#{member.slug}"
  end
end
