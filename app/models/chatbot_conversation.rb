class ChatbotConversation < ApplicationRecord
  ROLES = %w[user assistant system].freeze
  USER_TYPES = %w[distributor pd customer anonymous].freeze

  validates :session_id, :role, :message, presence: true
  validates :role, inclusion: { in: ROLES }

  scope :for_session, ->(sid) { where(session_id: sid).order(:created_at) }
  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }

  # 대화 응답 (LLM stub — 실제는 OpenAI/Anthropic 호출)
  def self.reply(session_id:, user_message:, user_type: "anonymous")
    # 사용자 메시지 저장
    create!(
      tenant_id: 1, session_id: session_id, user_type: user_type,
      role: "user", message: user_message
    )

    # FAQ 매칭 시도 (간단 키워드)
    faq = FaqKnowledgeBase.for_tenant.active.find { |f|
      f.keywords_list.any? { |k| user_message.include?(k) }
    }

    response = if faq
      faq.increment!(:match_count)
      faq.answer
    elsif ENV["OPENAI_API_KEY"].present?
      # TODO: OpenAI 실제 호출
      "[AI stub] OpenAI 키 감지됨 — 향후 실제 호출 구현 예정. 질문: #{user_message}"
    else
      "죄송합니다, 답변을 찾지 못했습니다. 관리자에게 문의해주세요."
    end

    create!(
      tenant_id: 1, session_id: session_id, user_type: user_type,
      role: "assistant", message: response,
      intent: faq ? "faq" : "fallback",
      metadata: (faq ? { matched_faq_id: faq.id } : {}).to_json
    )
    response
  end
end
