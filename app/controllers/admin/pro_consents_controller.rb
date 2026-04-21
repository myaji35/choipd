class Admin::ProConsentsController < Admin::BaseController
  def create
    consent = ProConsent.create!(
      tenant_id: 1,
      owner_id: current_admin_user.id,
      consent_type: params[:consent_type],
      consented: true,
      consent_text: ProConsent::TYPES.include?(params[:consent_type]) ? "동의함" : "",
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      consented_at: Time.current
    )
    redirect_to admin_kakao_inbox_index_path, notice: "동의 저장됨: #{params[:consent_type]}"
  end

  def revoke
    consent = ProConsent.granted.for_owner(current_admin_user.id).find_by(consent_type: params[:consent_type])
    consent&.revoke!
    redirect_to admin_kakao_inbox_index_path, notice: "동의 철회됨"
  end
end
