require "test_helper"

module Api
  module V1
    module Pd
      module Kanban
        class AuthTest < ActionDispatch::IntegrationTest
          test "GET /api/v1/pd/kanban/projects without auth returns 401" do
            get "/api/v1/pd/kanban/projects"
            assert_response :unauthorized
          end

          test "POST /api/v1/pd/kanban/projects without auth returns 401" do
            post "/api/v1/pd/kanban/projects", params: { project: { title: "x" } }
            assert_response :unauthorized
          end

          test "GET /api/v1/pd/kanban/columns without auth returns 401" do
            get "/api/v1/pd/kanban/columns"
            assert_response :unauthorized
          end

          test "GET /api/v1/pd/kanban/tasks without auth returns 401" do
            get "/api/v1/pd/kanban/tasks"
            assert_response :unauthorized
          end

          test "PATCH /api/v1/pd/kanban/tasks/:id without auth returns 401" do
            patch "/api/v1/pd/kanban/tasks/1", params: { task: { title: "x" } }
            assert_response :unauthorized
          end

          test "DELETE /api/v1/pd/kanban/tasks/:id without auth returns 401" do
            delete "/api/v1/pd/kanban/tasks/1"
            assert_response :unauthorized
          end
        end
      end
    end
  end
end
