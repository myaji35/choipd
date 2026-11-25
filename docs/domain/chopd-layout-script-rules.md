# chopd 레이아웃 화면 동작 규칙 (ISS-543, ISS-539 후속)

대상: `app/views/layouts/chopd.html.erb` · `_chopd_header.html.erb` 인라인 스크립트(Turbo 이동 때 다시 실행됨)

ISS-539 는 화면 스크립트 수정이라 새 업무(돈·회원·문의 저장) 규칙은 없다. 방문자가 겪는 화면 동작 규칙만 정리한다.

| ID | 역할 | 규칙 | 자동 점검 |
|---|---|---|---|
| R1 | 방문자 | 메뉴·바닥글 링크로 이동한 화면의 본문(.reveal)이 스크롤하면 모두 보인다 | `node script/qa/turbo_reveal_check.cjs` (revealHidden 0) |
| R2 | 방문자 | 이동을 반복해도 스크롤 진행바·헤더 배경 리스너가 늘지 않는다 | 같은 스크립트 scrollListenerGrowth 0 |
| R3 | 방문자 | chopd 화면 이동·조작 중 브라우저 오류가 없다 | turbo_reveal_check consoleErrors 0, `node script/qa/footer_inquiry_flow.cjs` |
| R4 | 모바일 방문자 | 햄버거를 누르면 메뉴가 한 번에 열리고 다시 누르면 닫힌다 — Turbo 이동 뒤에도 같다 | `node script/qa/chopd_mobile_menu_check.cjs` |
| R5 | 보조기기 사용자 | 햄버거 버튼이 열림 상태를 aria-expanded 로 알린다 | 같은 스크립트 expanded true/false |

## 이번에 찾아 고친 갭
- R3·R4: 메뉴(`#mobile-nav`)가 `<header data-controller="mobile-menu">` 밖에 있어 클릭마다 Stimulus "Missing target element menu" 오류가 났다(메뉴는 인라인 스크립트로 열려서 눈에는 안 띔). 1141a68 에서 chopd 헤더의 Stimulus 연결을 걷어 내고 인라인 토글만 남김.
- R5: 버튼에 열림 상태 알림이 없었다 → aria-expanded 추가.
