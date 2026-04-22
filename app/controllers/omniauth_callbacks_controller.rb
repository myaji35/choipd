# Google OAuth2 콜백 핸들러
# - provider 콜백 성공 → Member.from_omniauth로 찾거나 생성
# - 세션에 member_id 저장 → 회원 본인 admin(/:slug/admin)으로 리다이렉트
class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :google_oauth2, :failure ]

  def google_oauth2
    auth = request.env["omniauth.auth"]
    unless auth
      redirect_to root_path, alert: "OAuth 응답이 없습니다." and return
    end

    member = Member.from_omniauth(auth)
    if member&.persisted?
      session[:member_id] = member.id
      member.update(last_sign_in_at: Time.current) rescue nil

      # 신규 가입자는 승인 대기 안내 페이지로
      if member.status == "pending_approval"
        redirect_to root_path, notice: "환영합니다, #{member.name}님! 관리자 승인 후 페이지를 편집할 수 있습니다."
      else
        # 승인된 회원 → 본인 편집기로
        redirect_to "/#{member.slug}/admin/dashboard", notice: "다시 오신 걸 환영합니다, #{member.name}님."
      end
    else
      Rails.logger.error "[OAuth] Member 생성 실패: #{member&.errors&.full_messages&.join(', ')}"
      redirect_to root_path, alert: "로그인에 실패했습니다. 관리자에게 문의해주세요."
    end
  rescue StandardError => e
    Rails.logger.error "[OAuth] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to root_path, alert: "OAuth 처리 중 오류가 발생했습니다."
  end

  # OmniAuth failure 콜백 (user cancelled, invalid_credentials 등)
  def failure
    msg = params[:message].presence || "unknown"
    Rails.logger.warn "[OAuth/failure] #{msg}"
    redirect_to root_path, alert: "로그인이 취소되었거나 실패했습니다 (#{msg})."
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "로그아웃되었습니다."
  end
end
