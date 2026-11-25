module ScanOrganizer
  module AiProviders
    class Gemini < Base
      MODELS_URL = "https://generativelanguage.googleapis.com/v1beta/models"

      private

      def classify_url
        model = ENV.fetch("SCAN_ORGANIZER_GEMINI_MODEL", "gemini-3.5-flash-lite")
        "#{MODELS_URL}/#{model}:generateContent"
      end

      def headers(api_key)
        { "x-goog-api-key" => api_key }
      end

      def payload(image, mime_type)
        {
          contents: [ { parts: [ { text: PROMPT }, { inline_data: { mime_type: mime_type, data: image } } ] } ],
          generationConfig: { responseMimeType: "application/json" }
        }
      end

      def response_text(response)
        Array(response.dig("candidates", 0, "content", "parts")).pluck("text").join
      end
    end
  end
end
