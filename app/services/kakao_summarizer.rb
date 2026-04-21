# 카카오 대화 요약/감지 엔진
# 핵심 출력: "사장님이 답해야 할 것 3줄 + 오늘 요약 3줄"
class KakaoSummarizer
  def self.run_for_date(channel:, date: Date.current)
    new(channel: channel, date: date).run
  end

  def initialize(channel:, date:)
    @channel = channel
    @date = date
    @messages = channel.kakao_messages.for_date(date).where(purged: false).order(:received_at)
  end

  def run
    return nil if @messages.empty?

    must_reply = pick_must_reply(@messages)
    daily = pick_daily_summary(@messages)

    summary = KakaoSummary.find_or_initialize_by(
      kakao_channel_id: @channel.id, summary_date: @date
    )
    summary.assign_attributes(
      tenant_id: @channel.tenant_id,
      must_reply_lines: must_reply.to_json,
      daily_summary_lines: daily.to_json,
      total_messages: @messages.size,
      unanswered_count: @messages.where(replied: false).size,
      urgent_count: @messages.where("urgency_score >= 70").size,
      model: ENV["ANTHROPIC_API_KEY"].present? ? "claude-haiku" : "stub-1.0",
      generated_at: Time.current
    )
    summary.save!
    summary
  end

  private

  # "사장님이 직접 답해야 할 것 3줄"
  # 휴리스틱: 미답변 + 질문 또는 긴급도 ≥ 50, 우선순위 정렬
  def pick_must_reply(messages)
    candidates = messages
      .where(replied: false)
      .where("urgency_score >= ? OR question_kind = ?", 50, "question")
      .order(urgency_score: :desc, received_at: :asc)
      .limit(3)

    if candidates.empty?
      ["오늘은 답변이 필요한 긴급 문의가 없습니다."]
    else
      candidates.map { |m|
        prefix = m.urgency_score >= 80 ? "🚨" : m.question_kind == "question" ? "❓" : "💬"
        "#{prefix} #{m.sender_display || '고객'}: #{truncate(m.body, 60)}"
      }
    end
  end

  # "오늘 요약 3줄"
  def pick_daily_summary(messages)
    total = messages.size
    questions = messages.where(question_kind: "question").size
    complaints = messages.where(question_kind: "complaint").size
    answered = messages.where(replied: true).size
    answer_rate = total.zero? ? 0 : (answered.to_f / total * 100).round

    [
      "오늘 #{total}건 문의가 들어왔어요. (#{questions} 질문, #{complaints} 불만)",
      "답변율 #{answer_rate}% (#{answered}/#{total}). 미답변 #{total - answered}건은 inbox에 있어요.",
      most_active_sender_summary(messages)
    ]
  end

  def most_active_sender_summary(messages)
    grouped = messages.group(:sender_kakao_id).count
    return "오늘 가장 활발한 대화 상대가 없습니다." if grouped.empty?
    top_sender_id, count = grouped.max_by { |_, c| c }
    sender = messages.where(sender_kakao_id: top_sender_id).first
    name = sender&.sender_display || "익명"
    "오늘 가장 자주 연락한 분: #{name} (#{count}회) - 따로 챙겨보세요."
  end

  def truncate(text, len)
    text.to_s.length > len ? "#{text[0, len]}..." : text
  end
end
