class Admin::KakaoInboxController < Admin::BaseController
  before_action :set_channel, only: [ :show, :reply, :ack_alert ]

  def index
    @channels = KakaoChannel.for_tenant.for_owner(current_admin_user.id)
    @subscription = ProSubscription.for_owner(current_admin_user.id).first
    @consents = {
      kakao: ProConsent.has_consent?(owner_id: current_admin_user.id, type: "kakao_data_processing"),
      customer: ProConsent.has_consent?(owner_id: current_admin_user.id, type: "customer_disclosure"),
      tos: ProConsent.has_consent?(owner_id: current_admin_user.id, type: "tos")
    }
  end

  def show
    @today_summary = @channel.kakao_summaries.find_by(summary_date: Date.current) ||
                     KakaoSummarizer.run_for_date(channel: @channel, date: Date.current)
    @unanswered = @channel.kakao_messages.unanswered.recent.limit(20)
    @urgent_alerts = @channel.kakao_alerts.unread.recent.limit(10)
    @recent_summaries = @channel.kakao_summaries.recent.limit(7)
  end

  # 채널 연결 시뮬레이션 (실제는 카카오 OAuth)
  def connect
    channel_id = params[:channel_id].presence || "@demo_#{SecureRandom.hex(4)}"
    channel_name = params[:channel_name].presence || "데모 채널"

    channel = KakaoChannel.create!(
      tenant_id: 1,
      owner_id: current_admin_user.id,
      owner_type: "AdminUser",
      channel_id: channel_id,
      channel_name: channel_name,
      status: "connected",
      connected_at: Time.current
    )
    KakaoKeyword.seed_for!(current_admin_user.id)
    redirect_to admin_kakao_inbox_path(channel), notice: "채널 연결됨"
  rescue ActiveRecord::RecordNotUnique
    redirect_to admin_kakao_inbox_index_path, alert: "이미 연결된 채널입니다."
  end

  def reply
    msg = @channel.kakao_messages.find(params[:message_id])
    msg.reply!
    redirect_to admin_kakao_inbox_path(@channel), notice: "답변 완료 표시됨"
  end

  def ack_alert
    alert = @channel.kakao_alerts.find(params[:alert_id])
    alert.ack!
    redirect_to admin_kakao_inbox_path(@channel)
  end

  # 데모 메시지 시뮬레이션 (테스트용)
  def simulate
    @channel = KakaoChannel.find(params[:id])
    samples = [
      ["고객A", "환불 어떻게 받을 수 있나요? 너무 별로였어요"],
      ["고객B", "예약 변경하고 싶은데 가능할까요?"],
      ["고객C", "고소할 거예요. 답변 빨리 주세요!"],
      ["고객D", "친절하게 안내해주셔서 감사합니다"],
      ["고객E", "배송이 아직 안 왔어요 언제 오나요?"]
    ]
    samples.each do |name, body|
      msg = @channel.kakao_messages.create!(
        tenant_id: 1, sender_kakao_id: "demo_#{name}", sender_display: name,
        body: body, received_at: Time.current
      )
      cls = KakaoMessageClassifier.classify(body, channel: @channel)
      msg.update!(question_kind: cls[:kind], urgency_score: cls[:urgency_score])
      if msg.urgency_score >= 70
        KakaoAlert.create!(
          tenant_id: 1, kakao_channel_id: @channel.id, kakao_message_id: msg.id,
          alert_type: "urgent_keyword", keyword: cls[:matched_keywords].first&.keyword,
          severity: (msg.urgency_score / 20).clamp(1, 5),
          reason: "긴급도 #{msg.urgency_score}점"
        )
      end
    end
    KakaoSummarizer.run_for_date(channel: @channel, date: Date.current)
    redirect_to admin_kakao_inbox_path(@channel), notice: "샘플 메시지 5건 + 분류 + 요약 생성됨"
  end

  private

  def set_channel
    @channel = KakaoChannel.for_tenant.find(params[:id])
  end
end
