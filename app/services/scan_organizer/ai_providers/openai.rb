module ScanOrganizer
  module AiProviders
    class Openai < Base
      MODELS_URL = "https://api.openai.com/v1/models"
      CLASSIFY_URL = "https://api.openai.com/v1/chat/completions"

      private

      def headers(api_key)
        { "Authorization" => "Bearer #{api_key}" }
      end

      def payload(image, mime_type)
        {
          model: ENV.fetch("SCAN_ORGANIZER_OPENAI_MODEL", "gpt-4.1-mini"),
          response_format: { type: "json_object" },
          messages: [ { role: "user", content: [
            { type: "text", text: PROMPT },
            { type: "image_url", image_url: { url: "data:#{mime_type};base64,#{image}" } }
          ] } ]
        }
      end

      def response_text(response)
        response.dig("choices", 0, "message", "content")
      end
    end
  end
end
