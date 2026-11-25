require "test_helper"

class ScanOrganizer::AdaptersTest < ActiveSupport::TestCase
  test "checks the models endpoint with the correct credentials for each provider" do
    original_request = ScanOrganizer::Http.method(:request)
    credentials = {
      "gemini" => [ "https://generativelanguage.googleapis.com/v1beta/models", { "x-goog-api-key" => "fake-key" } ],
      "openai" => [ "https://api.openai.com/v1/models", { "Authorization" => "Bearer fake-key" } ],
      "anthropic" => [ "https://api.anthropic.com/v1/models", { "x-api-key" => "fake-key", "anthropic-version" => "2023-06-01" } ]
    }
    requests = []
    ScanOrganizer::Http.define_singleton_method(:request) do |method, url, headers:|
      requests << [ method, url, headers ]
    end

    credentials.each do |provider, (url, headers)|
      adapter = ScanOrganizer::AiProviders.for(provider)
      assert adapter.test_connection("fake-key")
      assert_equal [ Net::HTTP::Get, url, headers ], requests.last
    end
    assert_equal 3, requests.size
  ensure
    ScanOrganizer::Http.define_singleton_method(:request, original_request)
  end

  test "reports blank credentials and unsuccessful requests as failed connections" do
    original_request = ScanOrganizer::Http.method(:request)
    requests = []
    ScanOrganizer::Http.define_singleton_method(:request) do |*args, **|
      requests << args
      raise ScanOrganizer::Http::Error
    end

    adapter = ScanOrganizer::AiProviders.for("gemini")
    refute adapter.test_connection("")
    assert_empty requests
    refute adapter.test_connection("fake-key")
    assert_equal 1, requests.size
  ensure
    ScanOrganizer::Http.define_singleton_method(:request, original_request)
  end
end
