# ISS-584 디자인 리뷰 — chopd 바닥글 (ISS-560 후속)

대상: `app/views/layouts/_chopd_footer.html.erb` · 확인 화면 `/education`, `/works` × 1280·390·320 (2026-11-25)

## 측정
- `OUT_DIR=tmp/qa/r1125-read node script/qa/footer_readability_check.cjs` → 6화면 모두 최소 대비 5.30:1, 낱글자 줄바꿈 0, 가로 넘침 없음, 콘솔 오류 0 (pass)
- `ROUTES=/education,/works WIDTHS=1280,390,320 node script/qa/layout_check.cjs` → footerWrapped 0, hScroll false (pass)
- 증거: `qa/ISS-584/footer-education-1280.png`, `footer-education-390.png`, `footer-works-320.png`

## 7개 관점 점수 (각 10점)
| 관점 | 점수 | 근거 |
|---|---|---|
| 위계 | 9 | 서비스·연락처 링크(.7) > 소제목(.55) > 저작권(.5), 주황은 'B2B/B2G 문의하기' 하나뿐 |
| 가독성 | 9 | 최소 대비 5.30:1, 13px 본문 |
| 간격·정렬 | 9 | 1280 3단(2fr/1fr/1fr), 390·320 브랜드 한 줄 + 2단 |
| 반응형 | 9 | 320 에서도 넘침·낱글자 줄바꿈 없음 |
| 브랜드 일치 | 9 | 로고 점·문의 링크만 주황(#ff4d1c 계열), 어두운 바탕 |
| 행동 명확성 | 9 | 바닥글 끝에서 문의로 가는 길 하나가 눈에 띈다 |
| 군더더기 없음 | 8 | 하단 '교육·미디어·작품'이 서비스 목록과 겹친다(위계가 약해 방해는 적음) |
| **합계** | **62/70** | 통과 |

## 판단
결함 없음. 하단 중복 링크는 위계가 약해 고칠 필요가 낮아 카드로 만들지 않는다.
