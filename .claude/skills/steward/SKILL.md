---
name: steward
description: choipd 저장소에서 PR 감시(/steward·/ship) 중 따를 규칙
---

# PR 감시 규칙 (choipd)

## 확인할 검사
- GitHub Actions `CI`의 다섯 잡: `scan_ruby`, `scan_js`, `lint`, `test`, `secret_scan`.
- `deploy` 잡은 main push 에서만 돈다. PR 에서는 건너뛰는 것이 정상이다.

## 로컬에서 고칠 때 쓰는 명령
- 린트: `bin/rubocop` (자동 수정은 `bin/rubocop -a`, 안전한 교정만)
- 테스트: `bin/rails db:test:prepare && bin/rails test`
- 보안: `bin/brakeman --no-pager`, `bin/bundler-audit`

## 지켜야 할 것
- 커밋 메시지는 한국어로, `fix(ci): …` 처럼 유형 접두를 붙인다.
- 린트를 통과시키려고 `.rubocop.yml` 규칙을 끄거나 `# rubocop:disable` 을 붙이지 않는다. 코드를 고친다.
- 테스트를 지우거나 `skip` 처리해 통과시키지 않는다.
- `secret_scan` 이 실패하면 코드를 고치지 말고 멈춰서 알린다. 비밀값 회수는 사람이 한다.
- `config/credentials`, `config/master.key`, `.env*`, `.kamal/secrets` 는 읽거나 고치지 않는다.
- 이 PR 의 범위(CI 정리) 밖의 기능 변경은 하지 않는다.
