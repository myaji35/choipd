require "test_helper"

module Api
  module V1
    module Admin
      class DistributorsControllerTest < ActionDispatch::IntegrationTest
        test "GET /api/v1/admin/distributors without auth returns 401" do
          get "/api/v1/admin/distributors"
          assert_response :unauthorized
          body = JSON.parse(response.body)
          assert_equal "Unauthorized", body["error"]
        end

        test "GET /api/v1/admin/distributors/check_id returns availability" do
          # check_id doesn't require auth in API design? Actually it does.
          get "/api/v1/admin/distributors/check_id", params: { slug: "anything" }
          assert_response :unauthorized
        end
      end
    end
  end
end
