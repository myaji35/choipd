class AiGeneratedContent < ApplicationRecord
  CONTENT_TYPES = %w[sns_post email description summary tag].freeze
  STATUSES = %w[draft approved rejected published].freeze

  validates :content_type, :prompt, :generated_text, :model, :user_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :content_type, inclusion: { in: CONTENT_TYPES }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :recent, -> { order(created_at: :desc) }
  scope :draft, -> { where(status: "draft") }
  scope :approved, -> { where(status: "approved") }

  # AI 생성 (LLM stub)
  def self.generate(content_type:, prompt:, user_id:, user_type: "admin")
    text = if ENV["ANTHROPIC_API_KEY"].present?
      "[AI stub] Anthropic 키 감지됨 — 실제 호출 구현 예정.\n\n프롬프트: #{prompt}"
    elsif ENV["OPENAI_API_KEY"].present?
      "[AI stub] OpenAI 키 감지됨 — 실제 호출 구현 예정.\n\n프롬프트: #{prompt}"
    else
      "[AI 미연결] 외부 LLM API 키가 설정되지 않았습니다.\n\n샘플 응답: #{prompt} 에 대한 #{content_type} 콘텐츠"
    end

    create!(
      tenant_id: 1, content_type: content_type, prompt: prompt,
      generated_text: text, model: "stub-1.0",
      user_id: user_id, user_type: user_type, status: "draft"
    )
  end

  def approve!
    update!(status: "approved")
  end
end
