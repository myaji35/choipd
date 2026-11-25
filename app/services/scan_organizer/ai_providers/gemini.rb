module ScanOrganizer
  module AiProviders
    class Gemini < Base
      MODELS_URL = "https://generativelanguage.googleapis.com/v1beta/models"

      private

      def headers(api_key)
        { "x-goog-api-key" => api_key }
      end
    end
  end
end
