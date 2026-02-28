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
      end
    end

    resources :resources,    controller: "distributor_resources"
    resources :hero_images
    resources :newsletter,   only: [ :index ]
    resources :payments,     only: [ :index, :show ]
    resources :invoices,     only: [ :index, :show ]
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

  # ── 헬스체크 ──────────────────────────────────────────
  get "up" => "rails/health#show", as: :rails_health_check
end
