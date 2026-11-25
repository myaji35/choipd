module ScanOrganizer
  module AiProviders
    class Anthropic < Base
      MODELS_URL = "https://api.anthropic.com/v1/models"
      CLASSIFY_URL = "https://api.anthropic.com/v1/messages"

      private

      def headers(api_key)
        { "x-api-key" => api_key, "anthropic-version" => "2023-06-01" }
      end

      def payload(image, mime_type)
        {
          model: ENV.fetch("SCAN_ORGANIZER_ANTHROPIC_MODEL", "claude-haiku-5-5"),
          max_tokens: 2048,
          messages: [ { role: "user", content: [
            { type: "text", text: PROMPT },
            { type: "image", source: { type: "base64", media_type: mime_type, data: image } }
          ] } ]
        }
      end

      def response_text(response)
        Array(response["content"]).pluck("text").join
      end
    end
  end
end
