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
    social = type == "socialdoctors_exposure"
    if params[:decision] == "revoke"
      current&.revoke!
      notice = social ? "'SNS 대신 운영'을 그만뒀어요. 새 글이 올라가지 않아요." : "'우리 동네 광고'를 그만뒀어요. 새 광고가 실리지 않아요."
    elsif type == "townin_local_ads" && !ProConsent.current_for(@member.id, "socialdoctors_exposure")
      return redirect_to slug_admin_brand_consents_path(slug: @member.slug), alert: "먼저 'SNS 대신 운영'에 동의해 주세요."
    elsif !current
      ProConsent.create!(owner_id: @member.id, consent_type: type, consented: true,
                         consented_at: Time.current, consent_text: text,
                         ip_address: request.remote_ip, user_agent: request.user_agent)
      notice = social ? "'SNS 대신 운영'에 동의했어요. 운영팀이 준비를 시작해요." : "'우리 동네 광고'에 동의했어요. 지역 파트너 승인 뒤에 실려요."
    end
    redirect_to slug_admin_brand_consents_path(slug: @member.slug), notice: notice
  end
end
