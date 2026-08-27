# [미션] SocialDoctors 브랜드 노출 동의 + 전달 API 구현

> **발신**: 0017_SocialDoctors (대표님 지시 2026-08-10)
> **수신**: 0008_choi-pd (IMPD)
> **상태**: 0017 수신 구조는 **구현·커밋 완료**(`45ea578`). 이 문서의 IMPD 측 구현만 남았다.
> **원본 명세**: `/Volumes/E_SSD/02_GitHub.nosync/0017_SocialDoctors/docs/impd-brand-consent-api-spec.md`

## 0. 무엇을 왜

SocialDoctors 회원이 "추종할 브랜드"를 고를 수 있게, **IMPD 회원 중 노출에 동의한 사람만** SocialDoctors로 전달한다.

**동의 수집은 IMPD가 한다.** 회원과의 관계와 개인정보 처리 주체가 IMPD이기 때문이다. SocialDoctors가 IMPD 회원에게 직접 동의를 받는 구조는 만들지 않는다.

현재 IMPD에는 `social-pulse-client.ts`(IMPD → 0017 발행 요청)만 있다. **이번 미션은 반대 방향**(IMPD → 0017 브랜드 제공)이다.

---

## 1. 작업 3건

### 작업 1 — `ProConsent::TYPES`에 값 추가 ⚠️ **선행 필수**

`app/models/pro_consent.rb`가 화이트리스트로 막고 있다. **이걸 먼저 하지 않으면 나머지가 전부 validation에서 실패한다.**

```ruby
# app/models/pro_consent.rb  (현재)
TYPES = %w[kakao_data_processing customer_disclosure tos].freeze

# 변경
TYPES = %w[kakao_data_processing customer_disclosure tos socialdoctors_exposure].freeze
```

테이블·마이그레이션은 불필요하다. `pro_consents`에 `consented`, `consented_at`, `revoked_at`, `ip_address`, `user_agent`, `owner_id`가 이미 있고 `revoke!`와 `has_consent?`도 구현돼 있다.

### 작업 2 — 회원 마이페이지 동의 UI

**위치**: `MemberAdmin::` 네임스페이스 (회원 본인 대시보드). `Admin::ProConsentsController`는 **관리자가 대신 찍어주는** 화면이라 부적합하다 — 본인 동의여야 법적 효력이 있다.

- `MemberAdmin::BaseController`를 상속하면 `set_member` + `require_member_or_admin`이 적용된다.
- 동의 시: `owner_id: @member.id`, `consent_type: 'socialdoctors_exposure'`, `consented: true`, `consented_at: Time.current`, `ip_address: request.remote_ip`, `user_agent: request.user_agent`
- 철회 시: 기존 `revoke!` 사용 (`revoked_at` 기록 + `consented: false`). **하드 삭제 금지** — 증빙 보존.

**동의 문구** (그대로 써도 됨):
```
[선택] SocialDoctors 브랜드 노출 동의
내 프로필(이름, 소개, 직군, 지역, 프로필/커버 이미지, SNS 링크)이
SocialDoctors 마켓플레이스에 노출되어 홍보에 활용되는 것에 동의합니다.
· 노출 정보에 연락처(이메일·전화번호)는 포함되지 않습니다.
· 언제든 이 화면에서 철회할 수 있으며, 철회 시 노출이 중단됩니다.
```

> **반드시 선택 동의로.** 필수 동의로 묶거나 기본 체크 상태로 두면 개인정보보호법 위반 소지가 있다.

### 작업 3 — 전달 API

```
GET /api/socialdoctors/consented-brands?since={ISO8601}
Header: X-Api-Key: {발급 키}
```

⚠️ **`Api::V1::BaseController`를 상속하지 마라.** 그 컨트롤러는 `before_action :ensure_admin_user!`로 **관리자 세션**을 요구한다. 이건 서버-투-서버 호출이라 세션이 없다. `X-Api-Key` 검증만 하는 별도 베이스를 쓰거나 컨트롤러에서 직접 인증하라.

- 키는 **환경변수로만** 보관. 코드·문서에 평문 금지(secret-guard 대상).
- 인증 실패 → `401`.
- `since` 생략 시 전체, 지정 시 **그 시각 이후 변경분**(동의·철회·탈퇴·프로필 수정 포함).

**응답**:
```json
{
  "brands": [
    {
      "externalId":   "123",
      "slug":         "choi-pd",
      "name":         "최PD",
      "bio":          "영상으로 브랜드를 만듭니다",
      "profession":   "영상 프로듀서",
      "businessType": "1인기업",
      "region":       "서울",
      "profileImage": "https://.../profile.jpg",
      "coverImage":   "https://.../cover.jpg",
      "socialLinks":  { "instagram": "...", "youtube": "..." },
      "consentedAt":  "2026-08-01T00:00:00Z",
      "revokedAt":    null,
      "withdrawnAt":  null
    }
  ],
  "syncedAt": "2026-08-10T00:00:00Z"
}
```

**필드 매핑**:

| 응답 필드 | 소스 |
|---|---|
| `externalId` | `members.id` (0017이 `@@unique([source, externalId])` 키로 사용) |
| `slug` / `name` / `bio` / `profession` / `businessType`(`business_type`) / `region` | `members` 동명 컬럼 |
| `profileImage`(`profile_image`) / `coverImage`(`cover_image`) | 공개 URL이어야 함 |
| `socialLinks` | `members.social_links` → JSON 객체 |
| `consentedAt` | `pro_consents.consented_at` (`consent_type='socialdoctors_exposure'`) |
| `revokedAt` | `pro_consents.revoked_at` |
| `withdrawnAt` | `members.withdrawn_at` |

---

## 2. 반드시 지킬 3가지

**① 연락처를 보내지 마라.** `email`, `phone`은 응답에서 제외. 홍보 노출에 불필요하고, 넘기는 순간 0017이 개인정보 수탁자가 되어 위수탁 계약이 필요해진다.

**② 철회·탈퇴 건도 목록에 포함해서 보내라.** ← **가장 틀리기 쉬운 지점**
목록에서 빼버리면 0017은 "변경 없음"으로 읽어 **노출이 계속된다.** 반드시 `revokedAt` / `withdrawnAt`을 채워서 **포함**해 보내라. 0017이 이를 받아 `REVOKED` / `WITHDRAWN`으로 즉시 비활성화한다.

**③ 미동의자는 아예 제외.** `consent_type='socialdoctors_exposure'` 레코드가 없는 회원은 응답에 넣지 않는다.

---

## 3. 0017 측 현황 (이미 완료 — 참고용)

| 항목 | 내용 |
|---|---|
| 모델 | `Brand` + `BrandStatus{ACTIVE, REVOKED, WITHDRAWN}`, `@@unique([source, externalId])` |
| 동기화 | `lib/brand-sync.ts`의 `syncImpdBrands(since?)`, 12시간 주기 자동 실행 |
| API | `GET /api/brands`(공개) / `POST /api/brands`(동기화 트리거, 인증) |
| 철회 반영 | 레코드 보존 + status만 전환 → 재동의 시 자동 복구 |
| 미설정 시 | `IMPD_API_BASE`/`IMPD_API_KEY` 없으면 조용히 skip (현재 이 상태) |
| 실패 시 | HTTP·형식 오류는 throw + `console.error`. 빈 배열 위장 안 함 |

---

## 4. 연동 순서

1. **작업 1** (`TYPES` 추가) → 2 (동의 UI) → 3 (API) 순서 고정. 1이 선행되지 않으면 2·3이 동작하지 않는다.
2. API 키 발급 → **대표님께 전달** → 0017 `.env.production`에 `IMPD_API_BASE`, `IMPD_API_KEY` 주입
3. 0017에서 `POST /api/brands` 수동 1회 실행 → 동기화 확인
4. 이후 12시간 주기 자동
5. **철회 테스트 필수**: IMPD에서 1건 철회 → 동기화 → `GET /api/brands`에서 사라지는지 확인

---

## 5. 미결 — 대표님 확인 필요

- **API 키 발급 주체·전달 경로**
- **철회 반영 지연**: 12시간 주기면 최대 12시간 노출이 유지된다. 즉시성이 필요하면 IMPD가 철회 시 0017의 `POST /api/brands`를 웹훅으로 호출하는 방식 추가 검토.
- **페이지네이션**: 대상 회원이 수천 건 이상이면 필요. 현재 명세엔 없음.

---

## 6. 이 문서로 작업 시작하는 법

0008 디렉터리에서 새 Claude 세션을 열고:

```
docs/MISSION-socialdoctors-brand-consent.md 를 읽고 작업 1·2·3을 구현해줘.
작업 1(ProConsent::TYPES)이 선행 필수다.
```

0008의 harness registry(`.claude/issue-db/registry.json`)에 이슈로 등록해 진행하면 된다.
