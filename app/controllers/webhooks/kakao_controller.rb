require "openssl"
class Webhooks::KakaoController < ActionController::API
  def message
    channel = KakaoChannel.find_by(channel_id: params[:channel_id])
    return render(json: { error: "channel_not_found" }, status: 404) unless channel

    msg = channel.kakao_messages.create!(
      tenant_id: channel.tenant_id,
      sender_kakao_id: params[:sender_id],
      sender_display: params[:sender_name],
      body: params[:body],
      message_type: params[:type] || "text",
      received_at: Time.current
    )
    cls = KakaoMessageClassifier.classify(msg.body, channel: channel)
    msg.update!(question_kind: cls[:kind], urgency_score: cls[:urgency_score])

    if msg.urgency_score >= 70 || cls[:matched_keywords].any?
      kw = cls[:matched_keywords].first
      KakaoAlert.create!(
        tenant_id: channel.tenant_id,
        kakao_channel_id: channel.id,
        kakao_message_id: msg.id,
        alert_type: kw ? "urgent_keyword" : "complaint",
        keyword: kw&.keyword,
        severity: (msg.urgency_score / 20).clamp(1, 5),
        reason: "긴급도 #{msg.urgency_score}점#{kw ? " · 키워드: #{kw.keyword}" : ''}"
      )
    end
    render json: { success: true, message_id: msg.id, urgency: msg.urgency_score }
  rescue StandardError => e
    Rails.logger.error "[KakaoWebhook] #{e.message}"
    render json: { error: e.message }, status: 500
  end
end
