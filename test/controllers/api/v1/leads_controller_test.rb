require "test_helper"

module Api
  module V1
    class LeadsControllerTest < ActionDispatch::IntegrationTest
      test "POST /api/v1/leads creates a new lead" do
        assert_difference -> { Lead.count }, 1 do
          post "/api/v1/leads", params: { lead: { email: "newsletter@example.com" } }, as: :json
        end
        assert_response :created
        body = JSON.parse(response.body)
        assert body["success"]
        assert_equal "newsletter@example.com", body["data"]["email"]
      end

      test "POST /api/v1/leads rejects invalid email" do
        post "/api/v1/leads", params: { lead: { email: "not-email" } }, as: :json
        assert_response :unprocessable_entity
      end

      test "POST /api/v1/leads is idempotent on duplicate" do
        post "/api/v1/leads", params: { lead: { email: "twice@example.com" } }, as: :json
        assert_response :created
        assert_no_difference -> { Lead.count } do
          post "/api/v1/leads", params: { lead: { email: "twice@example.com" } }, as: :json
        end
      end
    end
  end
end
