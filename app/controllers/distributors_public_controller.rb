class DistributorsPublicController < ApplicationController
  layout "chopd"

  def show
    @distributor = Distributor.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError.new("Not Found")
  end
end
