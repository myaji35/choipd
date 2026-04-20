# Next.js → Rails API 엔드포인트 매핑 명세서

**총 184 API routes (38 네임스페이스)**

## 네임스페이스별 분포

| 네임스페이스 | 개수 | 우선순위 | Rails 라우팅 위치 |
|---|---|---|---|
| admin | 75 | P0~P2 | `namespace :admin do ... end` |
| pd | 19 | P0~P1 | `namespace :pd do ... end` |
| auth | 10 | P0 | Devise + 추가 sessions controller |
| ai | 8 | P2 | `namespace :api do namespace :ai end` |
| videos | 6 | P2 | RESTful resources |
| live | 5 | P2 | live_streams |
| chat | 5 | P3 | RESTful resources |
| tenants | 4 | P3 | RESTful + member routes |
| sns | 4 | P0 | RESTful + scheduled |
| impd | 4 | P1 | brand identity API |
| enrichment | 4 | P3 | enrichment cache API |
| upload | 3 | P0 | Active Storage direct upload |
| playlists | 3 | P2 | RESTful nested |
| campaigns | 3 | P1 | marketing campaigns |
| webhooks | 2 | P2 | inbound webhook receiver |
| profile | 2 | P0 | profile show/update |
| notifications | 2 | P1 | RESTful |
| member | 2 | P1 | member-scoped API |
| inquiries | 2 | P0 | RESTful |
| dashboard | 2 | P1 | dashboard data |
| 기타 단건 | 18 | 다양 | 개별 매핑 |

## Rails 라우팅 변환 원칙

### 1. RESTful 정규화
Next.js의 `/api/admin/distributors/[id]/approve` → Rails:
```ruby
namespace :api do
  namespace :admin do
    resources :distributors do
      member do
        post :approve
        post :reject
        post :suspend
        post :activate
      end
    end
  end
end
```

### 2. Dynamic segment `[id]` → `:id`
- Next.js: `/api/admin/distributors/[id]/identity`
- Rails: `/api/admin/distributors/:id/identity`

### 3. 비표준 액션 처리
- 단일 자원 액션: `member do ... end` (예: approve, reject, suspend)
- 컬렉션 액션: `collection do ... end` (예: check-id, bulk-import)

### 4. 응답 포맷
- Next.js: `Response.json(data)` / `NextResponse.json(data, { status })`
- Rails: `render json: data, status: :ok`
- ApplicationController에 공통 JSON helper 추가 (success/error 포맷 통일)

### 5. 인증 미들웨어
- Next.js: `middleware.ts`에서 Clerk + dev-mode 처리
- Rails: `before_action :authenticate_admin_user!` (Devise) + Pundit policy

## Phase 1 (P0) 매핑 — 60개 라우트

### auth (10) — Phase 0 Devise 정비 시 처리
| Next.js | Rails | 비고 |
|---|---|---|
| POST /api/auth/login | POST /auth/login | Devise sessions#create |
| POST /api/auth/logout | DELETE /auth/logout | Devise sessions#destroy |
| POST /api/auth/register | POST /auth | Devise registrations#create |
| GET /api/auth/me | GET /api/auth/me | 커스텀 — current_admin_user 반환 |
| POST /api/auth/forgot-password | POST /auth/password | Devise passwords#create |
| POST /api/auth/reset-password | PATCH /auth/password | Devise passwords#update |
| POST /api/auth/2fa/enable | POST /api/security/2fa/enable | Phase 2 (security) |
| POST /api/auth/2fa/verify | POST /api/security/2fa/verify | Phase 2 |
| POST /api/auth/2fa/disable | POST /api/security/2fa/disable | Phase 2 |
| GET /api/auth/sessions | GET /api/auth/sessions | 활성 세션 목록 |

### admin/distributors (8) — content 도메인
| Next.js | Rails |
|---|---|
| GET /api/admin/distributors | GET /api/admin/distributors |
| POST /api/admin/distributors | POST /api/admin/distributors |
| GET /api/admin/distributors/check-id | GET /api/admin/distributors/check_id (collection) |
| GET /api/admin/distributors/:id | GET /api/admin/distributors/:id |
| PATCH /api/admin/distributors/:id | PATCH /api/admin/distributors/:id |
| POST /api/admin/distributors/:id/approve | POST /api/admin/distributors/:id/approve (member) |
| POST /api/admin/distributors/:id/reject | POST /api/admin/distributors/:id/reject (member) |
| POST /api/admin/distributors/:id/suspend | POST /api/admin/distributors/:id/suspend (member) |
| POST /api/admin/distributors/:id/activate | POST /api/admin/distributors/:id/activate (member) |
| GET /api/admin/distributors/:id/identity | GET /api/admin/distributors/:id/identity (member) |

### admin/posts (2)
| Next.js | Rails |
|---|---|
| GET /api/admin/posts | GET /api/admin/posts |
| POST /api/admin/posts | POST /api/admin/posts |
| GET /api/admin/posts/:id | GET /api/admin/posts/:id |
| PATCH /api/admin/posts/:id | PATCH /api/admin/posts/:id |
| DELETE /api/admin/posts/:id | DELETE /api/admin/posts/:id |

### admin/inquiries, hero-images, newsletter, payments, invoices, profile, resources, settings — 동일 RESTful 패턴

### sns (4)
| Next.js | Rails |
|---|---|
| GET /api/sns/accounts | GET /api/sns/accounts |
| POST /api/sns/accounts | POST /api/sns/accounts |
| GET /api/sns/scheduled | GET /api/sns/scheduled_posts |
| POST /api/sns/scheduled | POST /api/sns/scheduled_posts |

### inquiries, leads (3)
| Next.js | Rails |
|---|---|
| POST /api/inquiries | POST /inquiries |
| POST /api/leads | POST /leads |
| GET /api/health | GET /up (kamal-proxy 호환) |

## Phase 2~4 매핑

(상세 매핑은 각 Phase 진입 시 도메인별로 확장)

### Phase 2 (P1) — analytics, security, kanban, member 관련 약 50 routes
- /api/admin/analytics/* (8)
- /api/admin/security/* (3)
- /api/admin/members/* (10)
- /api/pd/kanban/* (4)
- /api/notifications (2)
- ...

### Phase 3 (P2) — ai, automation, video, enterprise 관련 약 50 routes
- /api/ai/* (8)
- /api/admin/automation-templates (1)
- /api/admin/integrations/* (3)
- /api/admin/organizations/* (5)
- /api/videos/* (6)
- /api/live/* (5)
- /api/playlists/* (3)
- /api/watch-history (1)
- /api/webhooks (2)

### Phase 4 (P3) — chat, follower, pomelli, talent, tenant 관련 약 24 routes
- /api/chat/* (5)
- /api/tenants/* (4)
- /api/enrichment/* (4)
- /api/pomelli (1)
- /api/impd/* (4)

## Rails routes.rb 구조 (최종 형태 미리보기)

```ruby
Rails.application.routes.draw do
  # ── Devise 인증 ──
  devise_for :admin_users, path: "auth", controllers: {
    sessions: 'auth/sessions',
    registrations: 'auth/registrations',
    passwords: 'auth/passwords'
  }

  # ── 공개 사이트 ──
  scope module: :chopd do
    root "home#index"
    get "/education",   to: "education#index"
    get "/media",       to: "media#index"
    get "/works",       to: "works#index"
    get "/community",   to: "community#index"
    resources :inquiries, only: [:new, :create]
    resources :leads, only: [:create]
  end

  # ── Admin (HTML + JSON) ──
  namespace :admin do
    root "dashboard#index"
    resources :distributors do
      member { post :approve; post :reject; post :suspend; post :activate; get :identity }
      collection { get :check_id }
    end
    resources :posts, :inquiries, :hero_images, :payments, :invoices, :courses, :works
    resources :resources, controller: "distributor_resources"
    resources :newsletter, only: [:index]
    # Phase 2+
    namespace :analytics do
      resources :ab_tests
      resources :cohorts do
        resources :users, only: [:index]
      end
      resources :funnels, :reports
      get :rfm
      resources :events, only: [:index, :create]
    end
    namespace :security do
      post 'two_factor/enable'
      post 'two_factor/verify'
      post 'two_factor/disable'
    end
    resources :members do
      resources :documents, controller: "member_documents" do
        member { post :parse }
      end
      resources :skills, controller: "member_skills"
      member { get :monitor; post 'gap_report/generate' }
    end
    resources :organizations do
      resources :members, controller: "organization_members"
      resources :teams
      resource :branding, only: [:show, :update]
      resource :sso, only: [:show, :update]
    end
    resources :integrations do
      member { post :test }
    end
    resources :automation_templates
    resources :workflows do
      resources :executions, only: [:index, :show, :create]
    end
    post 'bulk_import/users', to: 'bulk_imports#create_users'
    get :backup, to: 'backup#index'
    get :health, to: 'health#index'
    get :logs, to: 'logs#index'
  end

  # ── PD 개인 대시보드 ──
  namespace :pd do
    root "dashboard#index"
    resource  :profile, only: [:edit, :update]
    resources :sns_accounts
    resources :scheduled_posts, controller: "sns_scheduled_posts"
    resources :hero_images
    resources :kanban_projects do
      resources :columns, controller: "kanban_columns"
      resources :tasks, controller: "kanban_tasks"
    end
  end

  # ── API (JSON) ──
  namespace :api do
    namespace :v1 do
      # 위 admin/pd 라우트와 동일 구조의 JSON 응답 버전
      # (Next.js API 호환 레이어)
    end
    namespace :ai do
      post :recommend
      post :embed
      post :chat
      post :generate
      post :score_quality
      post :tag_image
      get  :faq
      get  :activity_pattern
    end
    resources :videos do
      resources :chapters, :subtitles, :comments
    end
    resources :playlists do
      resources :videos, only: [:index, :create, :destroy]
    end
    resources :live_streams, path: 'live'
    resources :chat_conversations, path: 'chat' do
      resources :messages, controller: 'chat_messages'
    end
    resources :tenants do
      resources :members, controller: 'tenant_members'
    end
    resources :enrichment_caches, path: 'enrichment'
    post :webhooks, to: 'webhooks#receive'
    get :health, to: 'health#index'
    get '/auth/me', to: 'auth#me'
    get '/auth/sessions', to: 'auth#sessions'
  end

  # ── kamal-proxy healthcheck ──
  get :up, to: 'rails/health#show'
end
```

## 변환 시 주의사항

1. **Body parsing 차이**: Next.js는 `await req.json()`, Rails는 `params` 자동 파싱 (Strong Parameters 사용)
2. **인증 컨텍스트**: Next.js `auth()` from Clerk → Rails `current_admin_user` (Devise)
3. **CORS**: Next.js는 `next.config.js`에서, Rails는 `rack-cors` gem으로 처리
4. **파일 업로드**: Next.js의 FormData → Rails Active Storage (direct upload)
5. **Server Actions → Form POST**: Next.js Server Actions는 사용 안 함, Rails는 표준 form POST
6. **ISR/Streaming**: Next.js의 ISR은 Rails 측에서 Redis 캐시 + Russian doll caching으로 대체
