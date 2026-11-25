module ScanOrganizer
  module AiProviders
    class Base
      def test_connection(api_key)
        return false if api_key.blank?

        Http.request(Net::HTTP::Get, self.class::MODELS_URL, headers: headers(api_key))
        true
      rescue Http::Error
        false
      end
    end
  end
end
