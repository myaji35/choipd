class MemberSessionsController < ApplicationController
  layout "impd"
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
    @slug = params[:slug]
    @member = Member.publicly_visible.find_by(slug: @slug)
  end

  def create
    member = Member.find_by(slug: params[:slug])
    if member && member.withdrawn_at.blank? && member.password_digest.blank?
      redirect_to member_login_path, alert: oauth_only_login_alert and return
    end

    unless member && member.withdrawn_at.blank? && member.password_digest.present? && member.authenticate(params[:password].to_s)
      redirect_to login_member_path(slug: params[:slug]), alert: "비밀번호를 확인해주세요" and return
    end

    return if reject_unapproved_member(member)

    session[:member_id] = member.id
    member.update(last_sign_in_at: Time.current)
    redirect_to "/#{member.slug}/admin/dashboard", notice: "환영합니다, #{member.name}님"
  end

  def destroy
    slug = current_member&.slug
    session.delete(:member_id)
    redirect_to slug ? "/#{slug}" : "/", notice: "로그아웃됨"
  end
end
