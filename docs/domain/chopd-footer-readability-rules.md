# chopd 바닥글 가독성 규칙 (ISS-532·ISS-551 → ISS-559)

대상: `app/views/layouts/_chopd_footer.html.erb`, `app/views/layouts/chopd.html.erb`(본문 줄바꿈), 커밋 `ec66175`.
역할: 이 바닥글은 로그인 여부와 관계없이 모두(guest·member·admin)에게 같은 모양으로 보인다. 역할별 차이는 없다.

## 규칙

| ID | 규칙 | 역할 | 자동 점검 |
|---|---|---|---|
| R1 | 바닥글의 모든 글자(소개·소제목·링크·저작권)는 배경 #0a0e1a 위에서 대비 4.5:1 이상 | 모두 | `node script/qa/footer_readability_check.cjs` → `minContrast` ≥ 4.5, `contrastItems` 빈 배열 |
| R2 | 위계: 서비스·연락처 링크 > 소제목·하단 링크·저작권. 문의(B2B/B2G) 링크만 브랜드 주황 | 모두 | 같은 점검의 색 값 + 캡처 확인 (서비스 9.37, 하단 6.18, 저작권 5.30) |
| R3 | 한국어 문장은 단어 중간에서 줄이 바뀌지 않는다(`word-break: keep-all`) | 모두 | 같은 점검 `wordBreakItems` 빈 배열 |
| R4 | 긴 영문·주소가 있어도 가로 스크롤이 생기지 않는다(`overflow-wrap: break-word`) | 모두 | `ROUTES=/education,/works,/media,/community WIDTHS=1280,390,320 node script/qa/layout_check.cjs` → `hScroll false` |
| R5 | 바닥글에서 문의로 가는 길(B2B/B2G 문의하기)이 항상 보인다 | guest | 캡처 확인 + `bin/rails test test/integration/chopd_header_links_test.rb`(헤더·메뉴 링크 대상 존재) |

## 시나리오

| ID | 역할 | 흐름 | 기대 |
|---|---|---|---|
| S1 | guest | 390px /works 끝까지 스크롤 → 바닥글 소개·링크 읽기 | 소개 문장이 "통합 / 브랜드 허브."처럼 단어 단위로 줄바꿈, 모든 글자 4.5:1 이상 |
| S2 | guest | 1280px /education 바닥글 → 'B2B/B2G 문의하기' 누름 | 문의 화면(/inquiries/new)으로 이동, 콘솔 오류 0 |
| S3 | guest | 320px /education → 교육 소개 문장 | '강좌로'가 한 단어로 유지, 가로 스크롤 없음 |

## 검증 결과 (2026-11-25)
- footer_readability_check 6조합(/education·/works × 1280·390·320) minContrast 5.30, 대비·줄바꿈 위반 0, 콘솔 오류 0
- layout_check 15조합(/media/greeting 포함) hScroll false, clipped 0, 콘솔 오류 0
