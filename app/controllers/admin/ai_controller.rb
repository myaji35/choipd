class Admin::AiController < Admin::BaseController
  def index
    @rec_count = AiRecommendation.for_tenant.count
    @gen_count = AiGeneratedContent.for_tenant.count
    @faq_count = FaqKnowledgeBase.for_tenant.count
    @conv_count = ChatbotConversation.for_tenant.distinct.count(:session_id)
    @recent_generations = AiGeneratedContent.for_tenant.recent.limit(10)
    @top_faq = FaqKnowledgeBase.for_tenant.active.sorted.limit(10)
    @api_status = {
      openai: ENV["OPENAI_API_KEY"].present?,
      anthropic: ENV["ANTHROPIC_API_KEY"].present?
    }
  end
end
