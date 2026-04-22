# Townin ↔ imPD 파트너 통합 API 계약서

> **From**: imPD (choi-pd-rails · https://impd.townin.net)
> **To**: Townin (0014_Townin Graph)
> **Date**: 2026-04-22
> **Status**: **IMPLEMENTED · v1.0** — 양쪽 구현 완료 (Townin commit `7904ca2` · imPD commit `a12c30f`)
> **ISS-321**: imPD 회원 → Townin 파트너 승급 자동화

---

## 🎯 배경

imPD는 2-stage 회원 계층:
1. **일반 회원** (`status=approved`) — 본인 페이지 편집 등 소소한 활동
2. **Townin 파트너** (`partner_status=active`) — Townin에서 검증된 상위 회원. 공개 페이지에 파트너 배지 + 활동 섹션 자동 노출

imPD 관리자가 회원 상세 `/admin/members/:id`에서 "이메일로 조회" → Townin에 실제 사용자 있으면 user_id 자동 채움 → "파트너 승급" 클릭 → Townin에 `role=partner` 변경 요청.

---

## 🔗 확정된 엔드포인트 (v1.0)

### Base URL
```
TOWNIN_API_URL = https://api.townin.net/api/v1   (production, default)
```
로컬 개발 시 override: `http://localhost:3000/api/v1` 등

### 인증
모든 요청 헤더:
```
X-API-Key: <TOWNIN_API_KEY>
```
> `TOWNIN_API_KEY` = Townin 백엔드의 `CHOPD_API_KEY` env 값과 동일 시크릿

---

### [1] 이메일로 사용자 조회

```
GET {TOWNIN_API_URL}/users/lookup-by-email?email=72bumhee@gmail.com
X-API-Key: {TOWNIN_API_KEY}
```

#### 응답 — 성공 (HTTP 200)
Townin이 반환하는 사용자 객체 (구체 스키마는 Townin 구현 참조).
imPD에서 사용하는 핵심 필드:
- `id` / `user_id` — imPD의 `members.towningraph_user_id`에 저장
- `email` — `townin_email`
- `name` / `display_name` — `townin_name`
- `role` — `townin_role` (enum 아래 참조)

#### 응답 — 없음 (HTTP 404)
imPD는 폼에 "해당 이메일 없음" 안내 표시.

---

### [2] 역할 변경 (파트너 승급)

```
PATCH {TOWNIN_API_URL}/users/:id/upgrade-role
X-API-Key: {TOWNIN_API_KEY}
Content-Type: application/json

{
  "targetRole": "partner",
  "verification_id": "impd-member-42",
  "completed_at": null   // optional, ISO8601
}
```

#### 응답 — 성공
```jsonc
{
  "partnerId": "TWN-P-...",   // 있으면 imPD가 partner_notes에 기록
  // 기타 Townin 필드
}
```

#### 응답 — 조건 미달 (HTTP 400)
imPD는 alert로 사용자에게 메시지 전달.

#### 응답 — 사용자 없음 (HTTP 404)
imPD는 "User ID 재확인" 안내.

---

## 🎭 Role enum (Townin 실제 값)

imPD 폼의 "역할" placeholder에서 사용:
```
user / merchant / partner / fp / municipality
```
- `user` — 일반 사용자 (파트너 승급 전)
- `merchant` — 상점·가게
- `partner` — 파트너 (imPD가 승급 타겟)
- `fp` — 금융 전문가 (financial partner?)
- `municipality` — 지자체·공공

---

## 📦 imPD 구현 상세 (commit `a12c30f`)

### 파일 구조
```
app/services/townin_client.rb
  .enabled?                                  — TOWNIN_API_KEY 있는지
  .base_url                                  — ENV["TOWNIN_API_URL"] 또는 default
  .lookup_by_email(email)                    — GET /users/lookup-by-email
  .upgrade_role(user_id:, target_role:, ..)  — PATCH /users/:id/upgrade-role
  .request_with_key(req, uri)                — X-API-Key 헤더 자동 주입
  .parse_body(response) / .extract_message   — JSON 파싱 + 에러 추출

app/controllers/admin/members_controller.rb
  #lookup_townin      (GET)  — "이메일로 조회" 버튼
  #promote_partner    (POST) — "⭐ 파트너 승급" 버튼
    · TowninClient.upgrade_role 호출
    · 실패 시 로컬 상태 업데이트 금지 (양성화 원칙)
    · API 비활성 시 로컬만 fallback 승급
  #link_townin / #suspend_partner / #unlink_townin — 로컬 관리

app/views/admin/members/show.html.erb
  · "이메일로 조회" 섹션 + vanilla JS 자동 채움
  · 조회 성공 시 User ID/이메일/이름/역할 4개 필드 자동 입력
  · placeholder: user / merchant / partner / fp / municipality
```

### Error handling 계층
```ruby
TowninClient::Error           # 최상위
TowninClient::Unauthorized    # 401 — API key 오류
TowninClient::NotFound        # 404 — 사용자 없음
TowninClient::BadRequest      # 400 — 승급 조건 미달 등
```

### env 설정 (imPD)
```bash
# .env 또는 kamal secrets
TOWNIN_API_URL=https://api.townin.net/api/v1
TOWNIN_API_KEY=<Townin CHOPD_API_KEY와 동일>
```
프로덕션 배포 시 `.kamal/secrets` + `config/deploy.yml` env.secret으로 주입.

---

## ✅ 양쪽 체크리스트

### Townin 측 (완료)
- [x] `GET /api/v1/users/lookup-by-email?email=xxx` 엔드포인트 구현
- [x] `PATCH /api/v1/users/:id/upgrade-role` 엔드포인트 구현
- [x] X-API-Key 인증 미들웨어
- [x] CHOPD_API_KEY env 할당

### imPD 측 (완료)
- [x] `TowninClient` 서비스 클래스 (`app/services/townin_client.rb`)
- [x] `/admin/members/:id/lookup_townin` JSON 액션
- [x] `/admin/members/:id/promote_partner` Townin API 호출 반영
- [x] 회원 상세 UI "이메일로 조회" + 자동 채움 JS
- [x] Role enum placeholder (user/merchant/partner/fp/municipality)

### 배포 (대기)
- [ ] imPD 로컬 `.env`에 `TOWNIN_API_URL` · `TOWNIN_API_KEY` 주입 → 로컬 테스트
- [ ] `config/deploy.yml`의 `env.secret`에 `TOWNIN_API_KEY` 추가
- [ ] 프로덕션 `kamal deploy`
- [ ] 실제 회원(예: 72bumhee@gmail.com)으로 lookup → 승급 테스트

---

## 🔮 향후 확장 (아직 미구현)

### P2 · 개별 사용자 상세 조회 (현재는 이메일 lookup만)
```
GET /api/v1/users/:id
X-API-Key: ...
```
imPD가 파트너 상세 KPI(팔로워/게시물/평점)를 공개 페이지 §B-3에 노출하려면 필요.

### P3 · Webhook
파트너 상태 변경 시 Townin → imPD 푸시:
```
POST https://impd.townin.net/webhooks/townin/partner_changed
X-Townin-Signature: sha256=HMAC(secret, body)
```

### P4 · KPI 동기화
Townin의 `posts_count`, `followers_count`, `rating_avg` 등을 imPD의 `last_snapshot_json`에 주기 캐시.

---

## 버전 이력

- **v0.1 · 2026-04-22** · imPD 초안 작성 (질문 포함)
- **v1.0 · 2026-04-22** · Townin 구현 반영 (commit `7904ca2`) + imPD 구현 완료 (commit `a12c30f`). IMPLEMENTED 전환
