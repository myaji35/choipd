# 회원(Member) 전용 로그인 페이지.
# /auth/login — OAuth 버튼만 제공 (이메일/비밀번호 없음)
# 실제 로그인은 POST /auth/google_oauth2 → OmniauthCallbacksController
class MemberAuthController < ApplicationController
  layout "application"

  def new
    # 이미 로그인된 회원이면 본인 페이지로
    if session[:member_id].present?
      m = Member.find_by(id: session[:member_id])
      if m
        redirect_to "/#{m.slug}" and return if m.status == "approved"
        redirect_to root_path, notice: "#{m.name}님, 관리자 승인 대기 중입니다." and return
      end
    end
    # flash alert/notice 그대로 표시
  end
end
