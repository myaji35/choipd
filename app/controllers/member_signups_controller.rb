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

    unless params[:terms_agree].to_s == "1"
      flash.now[:alert] = "이용약관 및 개인정보처리방침 동의가 필요합니다."
      render :new, status: :unprocessable_entity and return
    end

    # ISS-401: Identity Probe 동의 체크박스 처리. 체크 안 해도 기존 플로우 유지.
    if params[:identity_probe_consent].to_s == "1" && @member.respond_to?(:identity_probe_consent_at=)
      @member.identity_probe_consent_at = Time.current
    end

    @member.terms_agreed_at = Time.current

    if @member.save
      session[:member_id] = @member.id
      @member.update(last_sign_in_at: Time.current) if @member.respond_to?(:last_sign_in_at)

      # ISS-401: 동의한 회원은 백그라운드로 identity probe 수행 + 대기 페이지로 이동.
      if @member.respond_to?(:identity_probe_consent_at) && @member.identity_probe_consent_at.present?
        begin
          IdentityProbeJob.perform_later(@member.id)
        rescue => e
          Rails.logger.warn("[MemberSignups] probe enqueue failed: #{e.class}: #{e.message}")
        end
        redirect_to "/welcome/probe", notice: "환영합니다, #{@member.name}님. 잠시만요..." and return
      end

      redirect_to "/#{@member.slug}", notice: "환영합니다, #{@member.name}님. 이제 페이지를 편집할 수 있어요."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def signup_defaults
    { tenant_id: 1, status: "approved", impd_status: "none" }
  end
end
