# 브랜드 채널 관리 기획 (2026-11-24)

대표님 지시(2026-11-24): "impd에서 회원이 관리하는 브랜드에 이같은 정보를 관리해야해." — 의뢰받은 회원 브랜드의 네이버 블로그·네이버 인물정보·LinkedIn·페북 페이지·인스타·쓰레드 등 채널을 대행 관리하기 위한 정보 관리.

## 1. 무엇을 관리하나
브랜드(`brands`) 하나에 채널 여러 개. 채널마다:

| 칸 | 뜻 |
|---|---|
| platform | naver_blog / naver_people / linkedin_profile / linkedin_page / facebook_page / instagram / threads / youtube / kakao_channel / other |
| account_handle | 로그인 아이디 또는 계정 이름(@핸들) |
| profile_url | 채널 주소 |
| connection_method | oauth(공식 연동) / ego_session(ego 브라우저 로그인) / manual(사람이 직접) |
| credential_ref | 비밀번호가 보관된 곳의 **이름표만** (예: M6 키체인 항목 `impd-brand-<brand_id>-<platform>`). 비밀번호 값은 imPD DB에 절대 저장하지 않는다 |
| sns_account_id / profile_account_id | 이미 있는 OAuth 연결(`sns_accounts`)·인물정보 점검(`profile_accounts`)과 연결(선택) |
| delegation_consent_at | 회원이 계정 관리 위탁에 동의한 시각(없으면 대행 게시 금지) |
| session_status | 연결됨 / 로그인 필요 / 오류 / 미점검 |
| last_checked_at, last_error | 마지막 점검 |
| posting_cadence | 약정 게시 주기(예: 주 2회) |
| notes | 메모 |

## 2. 채널별 기본 연결 방식
- facebook_page·instagram(비즈니스/크리에이터 + 페북 페이지 연결)·threads·linkedin(글 게시) → oauth (비밀번호 없음)
- naver_blog·naver_people·linkedin_profile(프로필·스페셜 편집) → ego_session (비밀번호는 M6 키체인, 회원별 ego 프로필)
- 인스타를 ego 로그인으로 게시하지 않는다(계정 잠김 위험, 과거 개인 계정 오게시 사고).

## 3. 화면
- 운영자 `/admin/brands/:id`: 채널 목록·추가·수정·삭제, 상태 색 표시(로그인 필요 = 빨강), 위탁 동의 여부.
- 회원 `/:slug/admin/brand`: 내 브랜드 채널 목록(읽기 + 주소·핸들 수정, 위탁 동의 체크). credential_ref 는 회원 화면에 보이지 않는다.

## 4. 지키는 것
- 비밀번호·토큰 값 입력 칸을 만들지 않는다. 토큰은 기존 `sns_accounts`(암호화) 경로만 쓴다.
- 위탁 동의 없는 채널에는 예약 게시를 만들 수 없다.
- 해지 시 회원에게 비밀번호 변경 안내.

## 5. 다음 단계(이번 범위 밖)
- ego 자동 게시 실행기(네이버 블로그), 세션 점검 순찰, 인스타·쓰레드·링크드인 게시 연동.
