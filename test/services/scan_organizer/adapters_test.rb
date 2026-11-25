require "test_helper"

class ScanOrganizer::AdaptersTest < ActiveSupport::TestCase
  test "classification reads the model environment on each request for every provider" do
    result = { category: "document", confidence: 0.9, fields: {} }.to_json
    responses = {
      "gemini" => { candidates: [ { content: { parts: [ { text: result } ] } } ] },
      "openai" => { choices: [ { message: { content: result } } ] },
      "anthropic" => { content: [ { text: result } ] }
    }
    defaults = { "gemini" => "gemini-3.5-flash-lite", "openai" => "gpt-4.1-mini", "anthropic" => "claude-haiku-5-5" }
    original_request = ScanOrganizer::Http.method(:request)

    test_case = self
    defaults.each do |provider, default_model|
      env_key = "SCAN_ORGANIZER_#{provider.upcase}_MODEL"
      original_model = ENV[env_key]
      adapter = ScanOrganizer::AiProviders.for(provider)
      [ nil, "custom-model" ].each do |override|
        ENV[env_key] = override
        expected = override || default_model
        ScanOrganizer::Http.define_singleton_method(:request) do |_, url, json:, **|
          if provider == "gemini"
            test_case.assert_equal "https://generativelanguage.googleapis.com/v1beta/models/#{expected}:generateContent", url
          else
            test_case.assert_equal expected, json.fetch(:model)
          end
          responses.fetch(provider).to_json
        end
        assert_equal "document", adapter.classify(api_key: "fake-key", image_bytes: "image", mime_type: "image/png")[:category]
      end
    ensure
      ENV[env_key] = original_model
    end
  ensure
    ScanOrganizer::Http.define_singleton_method(:request, original_request)
  end

  test "Drive inspection omits both tokens even after acquiring an access token" do
    adapter = ScanOrganizer::Cloud::GoogleDrive.new(refresh_token: "fake-refresh", scan_folder_id: "folder")
    original_request = ScanOrganizer::Http.method(:request)
    ScanOrganizer::Http.define_singleton_method(:request) do |method, _, **|
      method == Net::HTTP::Post ? { access_token: "fake-access", expires_in: 3600 }.to_json : "image"
    end

    assert_equal "image", adapter.download("file")
    assert_equal '#<ScanOrganizer::Cloud::GoogleDrive scan_folder_id="folder">', adapter.inspect
  ensure
    ScanOrganizer::Http.define_singleton_method(:request, original_request)
  end
end
