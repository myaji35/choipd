# 회원(Member) 전용 로그인 페이지.
# /auth/login — 이메일+비밀번호 또는 Google OAuth
# 이메일: 이 컨트롤러의 #create 가 직접 처리
# OAuth:  POST /auth/google_oauth2 → OmniauthCallbacksController
class MemberAuthController < ApplicationController
  layout "application"

  def new
    if redirect_if_signed_in
      return
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

    unless member
      # 보안상 "이메일이 없다"고 직접 말하지 않는다. 동일한 메시지로 통일.
      redirect_to member_login_path, alert: "이메일 또는 비밀번호가 일치하지 않습니다." and return
    end

    if member.password_digest.blank?
      redirect_to member_login_path,
                  alert: "이 계정은 Google 로그인으로 가입되어 있습니다. 아래 Google 버튼으로 계속해 주세요." and return
    end

    unless member.authenticate(password)
      redirect_to member_login_path, alert: "이메일 또는 비밀번호가 일치하지 않습니다." and return
    end

    case member.status
    when "pending_approval"
      redirect_to root_path, notice: "#{member.name}님, 관리자 승인 대기 중입니다." and return
    when "rejected"
      redirect_to root_path, alert: "가입이 거절된 계정입니다. 관리자에게 문의해 주세요." and return
    when "suspended"
      redirect_to root_path, alert: "정지된 계정입니다. 관리자에게 문의해 주세요." and return
    end

    session[:member_id] = member.id
    member.update(last_sign_in_at: Time.current) if member.respond_to?(:last_sign_in_at)
    redirect_to "/#{member.slug}", notice: "환영합니다, #{member.name}님"
  end

  private

  def redirect_if_signed_in
    return false if session[:member_id].blank?
    m = Member.find_by(id: session[:member_id])
    return false unless m
    if m.status == "approved"
      redirect_to "/#{m.slug}"
    else
      redirect_to root_path, notice: "#{m.name}님, 관리자 승인 대기 중입니다."
    end
    true
  end
end
