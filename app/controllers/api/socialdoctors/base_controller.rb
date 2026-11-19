class Api::Socialdoctors::BaseController < ActionController::API
  before_action :authenticate_api_key

  private

  def authenticate_api_key
    key = ENV["SOCIALDOCTORS_API_KEY"]
    return render json: { error: "API 키가 설정되지 않았습니다." }, status: :service_unavailable if key.blank?

    supplied = request.headers["X-Api-Key"].to_s
    unless supplied.bytesize == key.bytesize && ActiveSupport::SecurityUtils.secure_compare(supplied, key)
      render json: { error: "인증에 실패했습니다." }, status: :unauthorized
    end
  end
end
