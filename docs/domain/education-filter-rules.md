# 교육 화면 분류 필터 규칙 (ISS-534, ISS-531 후속)

대상: `/education` (Chopd::EducationController#index, `app/views/chopd/education/index.html.erb` 필터 바)

## 규칙
| ID | 역할 | 규칙 | 자동 검사 |
|---|---|---|---|
| R1 | 방문자 | 분류 없이 들어오면 공개된 과정 전부를 최신순으로 보여 주고 '전체' 버튼이 선택된다 | education_filter_test "shows all published courses with no filter" |
| R2 | 방문자 | 온라인·오프라인·B2B/B2G 를 누르면 그 분류의 공개 과정만 보이고 그 버튼 하나만 선택된다 | "shows only published courses of each selected type" |
| R3 | 방문자 | 알 수 없는 분류 값(주소창 오타 등)이나 빈 값은 '전체'로 처리한다 — 빈 목록·선택 없는 상태를 만들지 않는다 | "shows all published courses with an unknown or empty filter" |
| R4 | 방문자 | 비공개 과정은 어떤 분류에서도 보이지 않는다 | 세 테스트 공통 `.course-title` 비공개 제목 0건 |
| R5 | 방문자(보조기기) | 선택된 분류는 색뿐 아니라 `aria-current="page"` 로도 알린다(정확히 1개) | 세 테스트 공통 `a[aria-current]` count 1 |
| R6 | 방문자(모바일) | 390·320px 에서 분류 버튼 글자가 쪼개지지 않고 높이 32px 이상이다 | `ROUTES=/education WIDTHS=1280,390,320 node script/qa/layout_check.cjs` (pillWrapped 0, pillMinHeight 37.5) |

## 시나리오
- S1 모바일 방문자: 390px `/education` → '온라인' → 온라인 과정만 보이고 버튼 한 줄 유지
- S2 공유 링크 오타: `/education?type=onlne` → 전체 과정 + '전체' 선택 (수정 전: 빈 목록, 선택 없음)

## 이번에 고친 갭
- R3: 수정 전에는 `where(course_type: 'foo')` 로 빈 목록이 나오고 어떤 버튼도 선택되지 않았다(27e0f98 에서 수정).
- R5: 수정 전에는 선택 상태를 색으로만 구분했다(brand-dna 금지 패턴 "색만으로 상태 구분").
