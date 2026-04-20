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
        get  :identity
      end
      collection do
        get :check_id
      end
    end

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

  # ── 헬스체크 (kamal-proxy) ────────────────────────────
  get "up" => "rails/health#show", as: :rails_health_check
end
