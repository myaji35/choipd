# Next.js → Rails 완전 변환 마스터 플랜 (Option B)

**시작일**: 2026-04-20
**예상 기간**: 8~12주
**목표**: choi-pd-ecosystem (Next.js)의 모든 기능을 choi-pd-rails로 1:1 변환 후 `choipd.158.247.235.31.nip.io`에 배포

## 변환 범위 (Source of Truth)
- **DB 테이블**: 109개 (17 도메인)
- **API 엔드포인트**: 184개 route.ts
- **페이지(UI)**: 73개 page.tsx
- **Rails 현재**: 22 모델, 62 컨트롤러, 240 뷰 (약 30% 변환됨)

## 도메인별 테이블 분포 (변환 단위)
| 도메인 | 테이블 수 | 우선순위 | 비고 |
|---|---|---|---|
| content | 9 | P0 | courses/posts/works/leads/inquiries — 공개사이트 핵심 |
| distribution | 6 | P0 | distributors/resources — 분양 관리 |
| sns | 3 | P0 | SNS 연동 |
| kanban | 4 | P1 | PD 업무관리 |
| member | 7 | P1 | 회원/문서/스킬 |
| security | 8 | P1 | 인증/2FA/감사 |
| analytics | 8 | P1 | AB테스트/코호트/RFM |
| ai | 8 | P2 | 추천/임베딩/챗봇 |
| automation | 6 | P2 | 워크플로우/통합/웹훅 |
| video | 8 | P2 | VOD/라이브 |
| enterprise | 9 | P2 | 조직/팀/SSO/SLA |
| chat | 6 | P3 | 채팅 |
| follower | 5 | P3 | 팔로우 |
| pomelli | 4 | P3 | 비즈 정체성 |
| talent | 4 | P3 | 인재 |
| tenant | 4 | P3 | 멀티테넌시 |
| **합계** | **109** | | |

## Phase 구성 (12 Phases)

### Phase 0: 기반 정비 (3일)
- [ ] DB: SQLite → PostgreSQL 전환 결정 (Next.js는 LibSQL/Turso, Rails는 SQLite)
- [ ] Rails 8.1 ENV/Credentials 정비 (DATABASE_URL, JWT_SECRET, ENCRYPTION_KEY 등)
- [ ] GHCR `KAMAL_REGISTRY_PASSWORD` 발급/주입
- [ ] Devise → Clerk 호환 인증 전략 결정 (또는 Devise 단독 운영)
- [ ] CI/CD 파이프라인 (GitHub Actions + Kamal)
- [ ] 기존 Next.js DB 데이터 export 전략 (마이그레이션 시드)

### Phase 1: P0 핵심 (2주)
**도메인**: content (9) + distribution (6) + sns (3) = 18테이블
- [ ] 18개 모델 + Migration + Validation + Association
- [ ] 약 60개 API → Rails 컨트롤러/액션 변환
- [ ] 공개사이트(chopd) + Admin 분양관리 + SNS 연동 화면 완성
- [ ] RSpec 단위/통합 테스트 (커버리지 ≥ 80%)
- [ ] 마일스톤: 공개사이트 + 분양관리만으로 1차 배포 가능

### Phase 2: P1 비즈니스 (3주)
**도메인**: kanban (4) + member (7) + security (8) + analytics (8) = 27테이블
- [ ] 27개 모델 + Migration
- [ ] 약 50개 API 변환
- [ ] 회원관리/2FA/감사로그/AB테스트/코호트 분석 화면
- [ ] 마일스톤: PD 어드민 일상 업무 100% 가능

### Phase 3: P2 고급 (3주)
**도메인**: ai (8) + automation (6) + video (8) + enterprise (9) = 31테이블
- [ ] 31개 모델 + Migration
- [ ] 약 50개 API 변환
- [ ] AI 추천/챗봇/워크플로우/VOD/조직관리 화면
- [ ] 외부 서비스 연동 (OpenAI/Anthropic, GCS, 결제)

### Phase 4: P3 부가 (2주)
**도메인**: chat (6) + follower (5) + pomelli (4) + talent (4) + tenant (4) = 23테이블
- [ ] 23개 모델 + Migration
- [ ] 약 24개 API 변환
- [ ] 채팅/팔로우/멀티테넌시 화면

### Phase 5: 통합 검증 + 배포 (1~2주)
- [ ] 전체 시스템 E2E 테스트 (Playwright/System spec)
- [ ] 데이터 마이그레이션 리허설 (Next.js DB → Rails DB)
- [ ] 캐릭터 저니 테스트 (master/partner/소사장/일반유저 4 캐릭터)
- [ ] 성능 부하 테스트
- [ ] 프로덕션 배포 + 도메인 cut-over
- [ ] Next.js 컨테이너 폐기 (백업 보존)

## 자율 실행 전략 (GH_Harness)

### 이슈 자동 생성 규칙
각 Phase 시작 시:
1. 도메인별 `MIGRATE_DOMAIN` 이슈 생성 (예: `MIGRATE_CONTENT`, `MIGRATE_DISTRIBUTION`)
2. 도메인 내 테이블별 sub-issue 생성 (`MIGRATE_TABLE_courses`, ...)
3. 테이블별 sub-issue 완료 시 `RUN_TESTS` + `LINT_CHECK` 자동 파생
4. 모든 테이블 완료 후 도메인별 API 변환 이슈 생성
5. API 완료 후 UI(view) 변환 이슈 생성
6. UI 완료 후 `JOURNEY_VALIDATE` + `BIZ_VALIDATE` 자동 실행

### 에이전트 배치
- **plan-harness:product** → 도메인 단위 스토리 분해
- **agent-harness** (sonnet) → 모델/마이그레이션/컨트롤러/뷰 코드 생성
- **test-harness** → RSpec/System spec 작성·실행
- **biz-validator** → 비즈니스 로직 갭 검증
- **journey-validator** → 캐릭터 저니 테스트
- **brand-guardian** → UI 일관성 검증
- **cicd-harness** → Phase 완료 시 staging 배포

### 일일 운영
- 매일 첫 세션: `proactive-scan.sh` → 미완 이슈 / 타입 에러 / 테스트 실패 자동 처리
- 모든 이슈 완료 시 → 다음 도메인 자동 진입
- T2 (외부 영향/방향 전환/예산/보안) 발생 시만 대표님께 컨펌 요청

## 위험 요소 & 대응

| 위험 | 대응 |
|---|---|
| Drizzle ORM ↔ ActiveRecord 의미 차이 | 도메인별 schema diff 자동 생성, 누락 컬럼 자동 검출 |
| Next.js Server Actions → Rails Controllers 시그니처 차이 | API 호환 레이어 (Rails-side `/api/v1/*`) 우선 구축 |
| Clerk 인증 데이터 이전 | Phase 0에서 Devise 단독 운영 결정 시, 사용자 재가입 정책 합의 필요 |
| LibSQL → SQLite 데이터 이전 | `sqlite3 .dump` → `bin/rails db` import 스크립트 |
| 73개 페이지 디자인 일관성 | brand-dna.json 기반 brand-guardian 자동 검증 |
| 8주 동안 Next.js 신규 기능 추가 시 부채 누적 | Next.js feature freeze 정책 합의 (T2 컨펌 필요) |

## 결정이 필요한 T2 항목 (시작 전 답변 부탁)

1. **DB**: SQLite 유지 / PostgreSQL 전환 / 기존 LibSQL 유지 중 어느 것?
2. **인증**: Devise 단독 / Clerk 연동 유지 중 어느 것? (사용자 데이터 이전 영향)
3. **Next.js Feature Freeze**: 변환 기간 동안 Next.js에 신규 기능 추가 금지 동의?
4. **GHCR PAT**: 기존 토큰 보유 / 신규 발급 필요?
5. **데이터 보존**: Next.js의 기존 운영 데이터를 Rails로 이전 / 새로 시작?

## 성공 기준
- [ ] 109개 테이블 모두 Rails 모델로 변환됨
- [ ] 184개 API 엔드포인트 모두 Rails 라우트로 매핑됨
- [ ] 73개 페이지 모두 ERB로 변환되고 디자인 일관성 확보
- [ ] RSpec 커버리지 ≥ 80%
- [ ] System spec으로 4 캐릭터 저니 100% 통과
- [ ] `choipd.158.247.235.31.nip.io` 프로덕션 배포 + 5분 이상 무에러 운영
- [ ] Next.js 컨테이너 graceful shutdown
