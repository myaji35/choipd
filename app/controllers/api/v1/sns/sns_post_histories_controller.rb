module Api
  module V1
    module Sns
      class SnsPostHistoriesController < BaseController
        def index
          histories = SnsPostHistory.where(tenant_id: tenant_id).order(created_at: :desc)
          histories = histories.where(scheduled_post_id: params[:scheduled_post_id]) if params[:scheduled_post_id].present?
          render_success(histories.as_json)
        end

        def show
          history = SnsPostHistory.where(tenant_id: tenant_id).find(params[:id])
          render_success(history.as_json)
        end
      end
    end
  end
end
