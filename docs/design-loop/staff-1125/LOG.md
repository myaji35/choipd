# imPD 운영자·PD 관점 '회원 계정·채널 대행 등록' 흐름 루프 (2026-11-25, 10회)

릴레이 루프 GO(Gemini 10 / Codex 9). 목표: 회원 화면이 '운영자·PD에게 요청'이라 안내하는 일(네이버 인물정보·LinkedIn 계정, 네이버 블로그·페이스북·인스타 채널 등록과 위탁 동의)을 운영자(/admin)·PD(/pd)가 막힘 없이 처리하고 회원 대시보드·내 채널에 바로 보이게.
촬영: script/qa/staff_loop_shots.cjs (대상 회원: 새 회원 ux-member id25 = 계정·채널·브랜드 없음, 기존 회원 kang-seung-sig id4 / 개인 브랜드 22).
측정: 운영자 또는 PD가 회원 한 명의 계정·채널을 등록하고 회원 화면에서 확인하기까지 클릭 수·막힘 지점.

## 시작 관찰 (Opus)
- PD 프로필 계정 화면 실제 경로는 /pd/people_accounts (촬영 스크립트 경로 정정).
- PD 는 /admin 에 못 들어가므로 /admin/brands/:id/brand_channels(채널 등록)를 PD 가 할 길이 없어 보임 — 확인 필요.
- 새 회원(ux-member)은 브랜드가 0개 → 채널을 붙일 개인 브랜드부터 없음.
- 운영자 회원 목록(/admin/members) 390px 가로 넘침.
