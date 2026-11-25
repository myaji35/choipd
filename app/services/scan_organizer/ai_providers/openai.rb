module ScanOrganizer
  module AiProviders
    class Openai < Base
      MODELS_URL = "https://api.openai.com/v1/models"

      private

      def headers(api_key)
        { "Authorization" => "Bearer #{api_key}" }
      end
    end
  end
end
