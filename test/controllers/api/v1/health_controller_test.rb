require "test_helper"

module Api
  module V1
    class HealthControllerTest < ActionDispatch::IntegrationTest
      test "GET /api/v1/health returns ok" do
        get "/api/v1/health"
        assert_response :success
        body = JSON.parse(response.body)
        assert body["success"]
        assert_equal "ok", body["data"]["status"]
      end
    end
  end
end
