# ISS-480 이슈 체인이 4단계로 길어진 원인 — ISS-492

## 체인
| 카드 | 종류 | 결과 |
|---|---|---|
| ISS-480 | FIX_BUG (법적 고지 자리표시·사업자번호) | 1차 완료(bda7e51) → 실행기 재검증에서 **완료 기준 확인(criteria_check) 없음**으로 READY 복귀(recheck_reopens 1) → 2차 완료(5bdedd8) |
| ISS-483 / ISS-484 | 1차 완료 때 on_complete 가 만든 RUN_TESTS / DOMAIN_ANALYZE | 483 완료, 484 중복으로 CLOSED_SKIP |
| ISS-489 / ISS-490 | 2차 완료 때 on_complete 가 **같은 제목으로 다시** 만든 RUN_TESTS / DOMAIN_ANALYZE | 489 중복 정리, 490 은 이번 회차 처리 |
| ISS-485 | 보호책임자 공개 연락처 값 대기 | 대표님 값 대기(AWAITING_USER) |

## 근본 원인
1. **첫 마감에 완료 증거가 빠졌다.** 1차 완료 result 에 criteria_check·proof 가 없어 실행기 재검증이 카드를 READY 로 되돌렸다. 같은 카드가 두 번 완료되면서 파생 카드가 두 벌 생겼다.
2. **on_complete 의 중복 방지가 READY·IN_PROGRESS 만 본다.** `add_issue()` 는 같은 제목의 카드가 READY/IN_PROGRESS 일 때만 건너뛴다. 1차 파생 카드가 이미 DONE·CLOSED_SKIP 이면 2차 완료 때 똑같은 제목으로 다시 만든다. 코드가 바뀌었으니 시험(RUN_TESTS)을 다시 도는 것은 맞지만, 도메인 분석(DOMAIN_ANALYZE)처럼 결과가 커밋에 따라 바뀌지 않는 카드는 중복이다.
3. **대표님만 아는 값이 한 카드에 섞여 있었다.** 연락처 값이 정해지지 않아 일부만 끝낼 수 있었고, 나머지를 ISS-485 로 떼어 내며 체인이 하나 더 늘었다. 이것은 정상 분리다(값을 지어내지 않음).

## 재발 방지
- (원인 1) 공장 지시에 이미 있는 규칙을 지킨다: 카드를 마감할 때 result 에 기준별 criteria_check 와 다시 돌릴 수 있는 proof 명령을 반드시 넣는다. 빠지면 재검증이 되돌리고 파생 카드가 두 벌 생긴다.
- (원인 2) `.claude/hooks/on_complete.sh` 의 `add_issue()` 를 고쳤다(ISS-492): **같은 부모에서 같은 제목으로 이미 만든 분석형 카드(DOMAIN_ANALYZE·PATTERN_ANALYSIS·DESIGN_REVIEW 등 시험이 아닌 것)는 상태와 무관하게 다시 만들지 않는다.** 시험·점수 카드(RUN_TESTS·SCORE·LINT_CHECK)는 코드가 바뀌었을 수 있으므로 지금처럼 다시 만든다.
- (원인 3) 대표님 값이 필요한 부분은 처음부터 별도 카드(provide_value)로 떼고, 본 카드는 값 없이 끝낼 수 있는 범위로 기준을 쓴다.

## 참고
- 하네스 원본(GH_Harness)의 on_complete.sh 는 이 Mac 의 예전 경로(`/Volumes/E_SSD/02_GitHub.nosync/GH_Harness`)에 없다. `harness 업데이트`로 덮어쓰면 이 수정이 사라지므로 원본에도 같은 수정을 넣어야 한다.
