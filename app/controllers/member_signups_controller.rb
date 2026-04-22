# 회원 가입 (ISS-332).
# /auth/signup (GET/POST) — 이메일·비밀번호 기반 신규 회원 가입.
# 가입 직후 status="pending_approval" 로 저장. 관리자가 /admin/members 에서 승인해야
# 공개 페이지가 열리고 로그인도 가능.
#
# Google OAuth 가입은 기존 OmniauthCallbacksController 가 처리. 중복 없음.
class MemberSignupsController < ApplicationController
  layout "application"

  def new
    if session[:member_id].present? && Member.exists?(id: session[:member_id])
      redirect_to root_path, notice: "이미 로그인되어 있습니다." and return
    end
    @member = Member.new(signup_defaults)
  end

  def create
    permitted = params.require(:member).permit(:name, :email, :slug, :password, :password_confirmation, :business_type, :profession, :region)
    email = permitted[:email].to_s.strip.downcase

    if permitted[:password].to_s.length < 8
      @member = Member.new(permitted.merge(signup_defaults))
      @member.errors.add(:password, "는 8자 이상이어야 합니다")
      render :new, status: :unprocessable_entity and return
    end

    if permitted[:password] != permitted[:password_confirmation]
      @member = Member.new(permitted.merge(signup_defaults))
      @member.errors.add(:password_confirmation, "가 일치하지 않습니다")
      render :new, status: :unprocessable_entity and return
    end

    slug = permitted[:slug].presence || Member.generate_unique_slug(name: permitted[:name], email: email)

    @member = Member.new(
      signup_defaults.merge(
        name: permitted[:name],
        email: email,
        slug: slug,
        business_type: permitted[:business_type].presence || "individual",
        profession: permitted[:profession].presence || "custom",
        region: permitted[:region],
        password: permitted[:password],
        password_confirmation: permitted[:password_confirmation],
      ),
    )

    if @member.save
      # pending_approval 이므로 세션 생성하지 않음. 승인 후 로그인하라는 안내.
      redirect_to member_login_path, notice: "회원가입 완료. 관리자 승인 후 로그인할 수 있습니다. (이메일: #{email})"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def signup_defaults
    { tenant_id: 1, status: "pending_approval", impd_status: "none" }
  end
end
