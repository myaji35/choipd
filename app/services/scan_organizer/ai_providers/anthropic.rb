module ScanOrganizer
  module AiProviders
    class Anthropic < Base
      MODELS_URL = "https://api.anthropic.com/v1/models"

      private

      def headers(api_key)
        { "x-api-key" => api_key, "anthropic-version" => "2023-06-01" }
      end
    end
  end
end
