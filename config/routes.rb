Rails.application.routes.draw do
  # Devise 인증 (Admin/PD 공통)
  devise_for :admin_users, path: "auth", path_names: {
    sign_in: "login",
    sign_out: "logout"
  }

  # ── 공개 사이트 (Chopd) ──────────────────────────────
  root "chopd/home#index"

  scope module: :chopd do
    get "/education",        to: "education#index",  as: :education
    get "/media",            to: "media#index",      as: :media
    get "/media/greeting",   to: "media#greeting",   as: :media_greeting
    get "/works",            to: "works#index",      as: :works
    get "/community",        to: "community#index",  as: :community

    # 최범희 PD 개인 공개 페이지 (브랜드 변경 전 URL 유지)
    get "/choipd",           to: "home#index",       as: :choipd
  end

  # ── Legacy Next.js proxy ─────────────────────────────
  # /choi (클라이언트 공유 URL) — Phase 1 변환 누락분, Next.js impd 컨테이너로 reverse-proxy
  match "/choi(/*path)", to: "choi_proxy#proxy", via: :all, as: :choi_legacy
  match "/api/choi(/*path)", to: "choi_proxy#proxy", via: :all
  match "/_next(/*path)", to: "choi_proxy#proxy", via: :all  # Next.js static assets

  scope module: :chopd do

    resources :inquiries,    only: [ :new, :create ]
    resources :leads,        only: [ :create ]
  end

  # ── 분양 관리자 (Admin) ──────────────────────────────
  namespace :admin do
    root "dashboard#index"

    resources :distributors do
      member do
        post :approve
        post :reject
        post :suspend
        post :activate
      end
      collection do
        get :check_id
      end
      resource :identity, controller: "distributor_identities", only: [ :show, :update, :destroy ]
    end

    resources :members do
      member do
        post :approve
        post :reject
        post :suspend
        post :activate
      end
      resources :documents, controller: "member_documents", only: [ :index, :show, :create, :destroy ] do
        member { post :parse }
      end
      resources :skills, controller: "member_skills", only: [ :index ]
      resource :gap_report, controller: "member_gap_reports", only: [] do
        post :generate
      end
    end

    # ── 칸반 ─────────────────────────────────────
    get    "/kanban", to: "kanban#index", as: :kanban
    post   "/kanban/projects", to: "kanban#create_project", as: :kanban_projects
    get    "/kanban/projects/:id", to: "kanban#show", as: :kanban_project
    patch  "/kanban/projects/:id", to: "kanban#update_project"
    delete "/kanban/projects/:id", to: "kanban#destroy_project"

    scope "/kanban/projects/:project_id" do
      post   "/columns",          to: "kanban_columns#create",  as: :kanban_columns
      patch  "/columns/:id",      to: "kanban_columns#update",  as: :kanban_column
      delete "/columns/:id",      to: "kanban_columns#destroy"
      post   "/columns/reorder",  to: "kanban_columns#reorder", as: :kanban_columns_reorder

      post   "/tasks",                  to: "kanban_tasks#create",   as: :kanban_tasks
      patch  "/tasks/:id",              to: "kanban_tasks#update",   as: :kanban_task
      delete "/tasks/:id",              to: "kanban_tasks#destroy"
      post   "/tasks/:id/move",         to: "kanban_tasks#move",     as: :kanban_task_move
      post   "/tasks/:id/complete",     to: "kanban_tasks#complete", as: :kanban_task_complete
      post   "/tasks/:id/reopen",       to: "kanban_tasks#reopen",   as: :kanban_task_reopen
    end

    # ── 분석 ─────────────────────────────────────
    get "/analytics", to: "analytics#index", as: :analytics
    get "/analytics/events", to: "analytics#events", as: :analytics_events

    resources :ab_tests do
      member do
        post :start
        post :pause
        post :complete
      end
    end

    # ── 자동화 ───────────────────────────────────
    resources :workflows do
      member do
        post :execute
        post :toggle
      end
    end
    resources :integrations do
      member { post :test }
    end
    resources :webhooks do
      member { post :test }
    end

    # ── AI ───────────────────────────────────────
    get "/ai", to: "ai#index", as: :ai
    resources :faqs
    resources :ai_generations, only: [ :index, :show, :new, :create, :destroy ] do
      member { post :approve }
    end

    # ── Pro/Kakao 채널 어시스턴트 ──────────────────
    get  "/kakao_inbox", to: "kakao_inbox#index", as: :kakao_inbox_index
    post "/kakao_inbox/connect", to: "kakao_inbox#connect", as: :kakao_inbox_connect
    get  "/kakao_inbox/:id", to: "kakao_inbox#show", as: :kakao_inbox
    post "/kakao_inbox/:id/reply", to: "kakao_inbox#reply", as: :kakao_inbox_reply
    post "/kakao_inbox/:id/ack_alert", to: "kakao_inbox#ack_alert", as: :kakao_inbox_ack
    post "/kakao_inbox/:id/simulate", to: "kakao_inbox#simulate", as: :kakao_inbox_simulate

    resources :pro_subscriptions, only: [ :index, :show ] do
      collection { post :start_trial }
      member { post :activate; post :cancel }
    end
    post "/pro_consents",        to: "pro_consents#create", as: :pro_consents
    post "/pro_consents/revoke", to: "pro_consents#revoke", as: :pro_consents_revoke

    resources :resources,    controller: "distributor_resources"
    resources :hero_images
    resources :newsletter,   only: [ :index ]
    resources :payments,     only: [ :index, :show ] do
      member { post :refund }
    end
    resources :invoices,     only: [ :index, :show ] do
      member { post :resend }
    end
    resources :courses
    resources :posts
    resources :works
    resources :inquiries,    only: [ :index, :show, :update ]
  end

  # ── PD 개인 대시보드 ──────────────────────────────────
  namespace :pd do
    root "dashboard#index"

    resource  :profile,          only: [ :edit, :update ]
    resources :sns_accounts
    resources :scheduled_posts,  controller: "sns_scheduled_posts"
    resources :hero_images
    resources :leads,            only: [ :index ]
    resources :kanban_projects do
      resources :kanban_columns do
        resources :kanban_tasks
      end
    end
  end

  # ── API (JSON) — Phase 1 P0 ──────────────────────────
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      # 인증
      get  "auth/me",       to: "auth#me"
      get  "auth/sessions", to: "auth#sessions"

      # 헬스체크
      get  "health", to: "health#index"

      # 공개 폼
      resources :inquiries, only: [ :create ]
      resources :leads,     only: [ :create ]

      namespace :admin do
        resources :distributors do
          member do
            post :approve
            post :reject
            post :suspend
            post :activate
            get  :identity
          end
          collection do
            get :check_id
          end
        end
        resources :posts
        resources :inquiries, only: [ :index, :show, :update ]
        resources :hero_images
        resources :payments, only: [ :index, :show ] do
          member { post :refund }
        end
        resources :invoices, only: [ :index, :show ] do
          member { post :resend }
        end
        resources :courses
        resources :works
        resources :newsletter, only: [ :index, :destroy ]
        resource  :profile, only: [ :show, :update ]
        resource  :settings, only: [ :show, :update ]
        get :health, to: "health#index"
      end

      namespace :sns do
        resources :accounts, controller: "sns_accounts"
        resources :scheduled_posts, controller: "sns_scheduled_posts"
        resources :post_histories, controller: "sns_post_histories", only: [ :index, :show ]
      end
    end
  end

  # ── 외부 webhook (인증 없음) ───────────────────────
  post "/webhooks/kakao/message", to: "webhooks/kakao#message"

  # ── 헬스체크 (kamal-proxy) ────────────────────────────
  get "up" => "rails/health#show", as: :rails_health_check

  # ── 회원 본인 admin (/<slug>/admin/*) ─────────────────
  scope "/:slug", constraints: { slug: /[a-z0-9][a-z0-9\-]{1,}/ } do
    get  "/login",  to: "member_sessions#new",     as: :login_member
    post "/login",  to: "member_sessions#create",  as: :login_member_post
    delete "/logout", to: "member_sessions#destroy", as: :logout_member

    namespace :member_admin, path: "admin", as: :slug_admin do
      get "/",          to: redirect { |params, _req| "/#{params[:slug]}/admin/dashboard" }, as: :root
      get "/dashboard", to: "dashboard#show", as: :dashboard
      get "/editor",    to: "editor#show",    as: :editor
    end
  end

  # ── Vanity URL: /<slug> → 회원 또는 분양사 공개 페이지 (가장 마지막) ───
  # CRIT-4: SlugValidation::RESERVED_SLUGS 단일 source of truth.
  # 모델 검증과 라우트 차단이 동일 목록을 사용하므로 충돌 불가.
  get "/:slug",
      to: "public_profile#show",
      as: :public_profile,
      constraints: lambda { |req|
        slug = req.path_parameters[:slug].to_s
        slug.match?(/\A[a-z0-9][a-z0-9\-]{1,}\z/) && !SlugValidation::RESERVED_SLUGS.include?(slug)
      }
end
