# OmniAuth 설정 — Google OAuth2 (회원용)
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV["GOOGLE_OAUTH_CLIENT_ID"],
    ENV["GOOGLE_OAUTH_CLIENT_SECRET"],
    {
      scope: "email, profile",
      prompt: "select_account",
      image_aspect_ratio: "square",
      image_size: 200,
      skip_jwt: true,
      access_type: "online",
    }
end

# provider가 없는 개발 환경에서 초기화 실패 방지
OmniAuth.config.on_failure = proc { |env|
  OmniauthCallbacksController.action(:failure).call(env)
}

# POST만 허용 (CSRF 보호 — omniauth-rails_csrf_protection gem이 강제)
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true
