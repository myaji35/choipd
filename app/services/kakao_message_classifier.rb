# 메시지 분류 + 긴급도 스코어링 (Phase 1 프롬프트 자산 휴리스틱 버전)
class KakaoMessageClassifier
  def self.classify(body, channel:)
    new(body, channel).classify
  end

  def initialize(body, channel)
    @body = body.to_s
    @channel = channel
  end

  def classify
    {
      kind: detect_kind,
      urgency_score: compute_urgency,
      matched_keywords: matched_keywords
    }
  end

  private

  # 질문/진술/불만 3분류
  def detect_kind
    if @body.match?(/\?$|\?\s*$|어떻게|언제|얼마|있나요|되나요|할 수 있/)
      "question"
    elsif matched_keywords.any? { |k| %w[refund complaint legal].include?(k.category) }
      "complaint"
    else
      "statement"
    end
  end

  # 0-100 긴급도
  def compute_urgency
    score = 0
    matched_keywords.each { |k| score += k.weight }
    # 질문 보너스
    score += 20 if @body.match?(/\?/)
    # 짧은 다급한 메시지
    score += 10 if @body.length < 30 && @body.match?(/[!.]{2,}|급|빨리/)
    # 시간 지연 표현
    score += 15 if @body.match?(/언제|아직|왜 안|기다리|연락 없/)
    [score, 100].min
  end

  def matched_keywords
    @matched_keywords ||= begin
      owner = @channel.owner_id
      KakaoKeyword.for_owner(owner).active.select { |k| @body.include?(k.keyword) }
    end
  end
end
