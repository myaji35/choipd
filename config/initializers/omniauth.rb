# OmniAuth 설정 — Google OAuth2 (회원용)
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV["GOOGLE_OAUTH_CLIENT_ID"],
    ENV["GOOGLE_OAUTH_CLIENT_SECRET"],
    {
      scope: "email profile",
      prompt: "select_account",
      image_aspect_ratio: "square",
      image_size: 200,
      skip_jwt: true,
      access_type: "online",
      provider_ignores_state: false,
    }
end

OmniAuth.config.on_failure = proc { |env|
  OmniauthCallbacksController.action(:failure).call(env)
}

# omniauth-rails_csrf_protection은 POST request phase만 허용.
OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.silence_get_warning = true

# 개발 환경에서 OmniAuth 로그 레벨 상향 (디버깅)
OmniAuth.config.logger = Rails.logger if Rails.env.development?
