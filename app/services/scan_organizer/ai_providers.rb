module ScanOrganizer
  module AiProviders
    def self.for(name)
      {
        "gemini" => Gemini,
        "openai" => Openai,
        "anthropic" => Anthropic
      }.fetch(name) { raise ArgumentError, "지원하지 않는 AI 제공자입니다." }.new
    end
  end
end
