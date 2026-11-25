# 교육 화면 빈 강좌 안내 규칙 (ISS-578, ISS-552 후속)

대상: `/education` 빈 목록 상태 (`app/views/chopd/education/index.html.erb` `.empty-state`) · 강좌 카드 '문의하기' 버튼

ISS-552 는 빈 목록 안내 글자 대비(약 2.6:1)를 올리고 다음 행동(문의 링크)을 붙인 수정이다(3704c35). 필터 규칙은 `education-filter-rules.md` 를 따른다.

## 규칙
| ID | 역할 | 규칙 | 자동 점검 |
|---|---|---|---|
| R1 | 방문자 | 공개 강좌가 0개면 '등록된 강좌가 없습니다' 안내와 '원하는 강좌 문의하기' 링크(문의 양식)가 정확히 1개 보인다 | `bin/rails test test/integration/education_filter_test.rb` "shows the empty state with an inquiry link…" |
| R2 | 방문자 | 공개 강좌가 있으면 빈 안내와 그 링크는 나오지 않는다 | 같은 파일 "hides the empty state…" |
| R3 | 방문자 | 빈 안내 글자는 배경(#0a0e1a) 대비 4.5:1 이상이다 | 같은 파일 "empty state text meets WCAG contrast…" |
| R4 | 모바일 방문자 | 1280·390·320 에서 빈 안내·문의 링크가 가로 넘침·잘림 없이 보이고 링크 높이 44px 이상이다 | `ROUTES=/education WIDTHS=1280,390,320 node script/qa/layout_check.cjs` (2026-11-25 실측 pass) |
| R5 | 방문자 | 분류 필터로 그 분류 강좌만 0개일 때도 같은 빈 안내가 나온다 | R1 과 같은 화면 분기(`@courses.any?`) |
| R6 | 방문자 | 문의 링크를 눌러 온 방문자는 문의 유형(B2B/B2G 교육·일반 문의)을 고를 수 있어야 하고, 링크가 유형을 넘기면 그 유형이 미리 골라져 있어야 한다 | **자동 점검 없음 → 갭 G1** |

## 시나리오
- S1 강좌가 하나도 없을 때: `/education` → '원하는 강좌 문의하기' → `/inquiries/new?type=b2b` 200, 콘솔 오류 0
- S2 온라인 강좌만 없을 때: `/education?type=online` → 빈 안내 + 문의 링크
- S3 강좌 카드(외부 신청 링크 없음) '문의하기' → 문의 양식

## 찾은 갭
- G1 (R6): 빈 안내 링크와 강좌 카드 '문의하기'가 `?type=b2b` 를 넘기지만 `Chopd::InquiriesController#new` 는 `Inquiry.new` 만 만들어 유형 칸이 '선택하세요' 로 비어 있다. 넘긴 값이 아무 일도 하지 않아 방문자가 한 번 더 골라야 하고, 고르지 않으면 '문의 유형을 선택해 주세요' 오류를 만난다 → 버그 카드.
- 관찰: 빈 안내는 개인 방문자도 보는데 링크가 B2B 유형을 넘긴다. G1 을 고칠 때 빈 안내 링크는 '일반 문의'(contact)를 넘기는 쪽이 개인 방문자에게 맞다.
