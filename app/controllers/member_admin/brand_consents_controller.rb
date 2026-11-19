class MemberAdmin::BrandConsentsController < MemberAdmin::BaseController
  def show
    @consents = ProConsent::BRAND_CONSENT_TEXTS.keys.index_with do |type|
      ProConsent.for_owner(@member.id).where(consent_type: type).order(consented_at: :desc, id: :desc).first
    end
  end

  def update
    type = params[:consent_type]
    text = ProConsent::BRAND_CONSENT_TEXTS[type]
    return head :bad_request unless text && %w[grant revoke].include?(params[:decision])

    current = ProConsent.current_for(@member.id, type)
    if params[:decision] == "revoke"
      current&.revoke!
    elsif type == "townin_local_ads" && !ProConsent.current_for(@member.id, "socialdoctors_exposure")
      return redirect_to slug_admin_brand_consents_path(slug: @member.slug), alert: "먼저 SocialDoctors 브랜드 노출에 동의해 주세요."
    elsif !current
      ProConsent.create!(owner_id: @member.id, consent_type: type, consented: true,
                         consented_at: Time.current, consent_text: text,
                         ip_address: request.remote_ip, user_agent: request.user_agent)
    end
    redirect_to slug_admin_brand_consents_path(slug: @member.slug), notice: "동의 상태를 변경했습니다."
  end
end
