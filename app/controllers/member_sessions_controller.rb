class MemberSessionsController < ApplicationController
  layout "impd"

  def new
    @slug = params[:slug]
    @member = Member.find_by(slug: @slug)
  end

  def create
    member = Member.find_by(slug: params[:slug])
    if member && (member.password_digest.blank? || member.authenticate(params[:password].to_s))
      session[:member_id] = member.id
      member.update(last_sign_in_at: Time.current)
      redirect_to "/#{member.slug}/admin/dashboard", notice: "환영합니다, #{member.name}님"
    else
      redirect_to login_member_path(slug: params[:slug]), alert: "비밀번호를 확인해주세요"
    end
  end

  def destroy
    slug = current_member&.slug
    session.delete(:member_id)
    redirect_to slug ? "/#{slug}" : "/", notice: "로그아웃됨"
  end

  private

  def current_member
    @current_member ||= Member.find_by(id: session[:member_id])
  end
  helper_method :current_member
end
