# Identity Probe Engine — 기획서

**코드네임**: IdentityProbe
**UX 문구**: "imPD가 당신을 대신 찾아드릴게요"
**목적**: 이메일+이름만으로 SNS·웹·공개 DB에서 회원 정체성 단서를 자동 수집 → 프로필 초안 제시 → 회원은 결정만.

## 핵심 스펙

### 입력
- email (필수), name (선택), profession_hint (선택), region_hint (선택)

### 출력 — identity_probes 테이블
```ruby
create_table :identity_probes do |t|
  t.references :member, foreign_key: true, null: false
  t.string  :status, default: "pending"  # pending|completed|failed|expired|rejected|in_progress
  t.float   :confidence
  t.text    :identity      # JSON 직렬화 (SQLite)
  t.text    :sources_queried
  t.text    :sources_hit
  t.text    :raw_signals   # 30일 후 퍼지
  t.integer :last_step, default: 0
  t.text    :step_payloads # JSON
  t.string  :user_decision  # accepted|partial|rejected
  t.datetime :decided_at
  t.datetime :expires_at   # 기본 24h
  t.timestamps
end
add_index :identity_probes, [:member_id, :status]

# Member 테이블에 추가
add_column :members, :identity_probe_consent_at, :datetime
```

### 데이터 소스 (MVP 4개)

| # | 소스 | 한도 | 추출 신호 |
|---|---|---|---|
| 1 | Gravatar | 무제한 | 아바타, bio |
| 2 | Google CSE | 100/일 무료 | 블로그, 기사 |
| 3 | Naver 검색 API | 25k/일 무료 | 한국어 블로그·카페 |
| 4 | Instagram oEmbed | 무제한 | 공개 프로필 메타 |

### 파이프라인 (15초 예산)

```
0.0s  IdentityProbeJob.perform_later(member.id)
0.1s  [병렬] Gravatar + Google CSE + Naver + IG oEmbed (3s)
3.1s  [Haiku] raw signals → structured JSON (5s)
8.1s  [Sonnet] 신호 병합 + bio 재작성 (4s)
12s   DB 저장 + ActionCable push
13s   회원 눈앞에 초안 등장
```

### LLM 호출
- **Haiku 4.5** (Extract): raw HTML/JSON에서 이름·역할·지역·bio 문장 추출
- **Sonnet 4.6** (Rank+Copy): conflicting signals 병합, confidence 산정, bio 매니페스토 톤 재작성

### 비용
- probe 1건당 ~$0.012 (1,000건/월 = $12)

### PIPA 동의
- 가입 폼에 `identity_probe_consent_at` 체크박스 — 선택 항목
- 공개된 정보만 수집
- raw_signals 30일 후 자동 퍼지
- 회원 삭제 요청 시 즉시 제거 + blocklist 추가

### 실패 복구
- API 할당량 소진 → probe=null로 가입 진행 (기능 유지)
- LLM 환각 → bio_source_quote 원본 diff 리젝
- 오매칭 → 회원이 S1에서 "제가 아니에요" 체크

## 구현 파일 맵

```
db/migrate/
  20260424120000_add_identity_probe_consent_to_members.rb
  20260424120001_create_identity_probes.rb

app/
  models/identity_probe.rb
  jobs/identity_probe_job.rb
  services/identity_probe/
    orchestrator.rb
    sources/base_source.rb
    sources/gravatar_source.rb
    sources/google_cse_source.rb
    sources/naver_search_source.rb
    sources/instagram_oembed_source.rb
    llm/extract_haiku.rb
    llm/rank_copy_sonnet.rb
  controllers/
    identity_probes_controller.rb  # /welcome/probe 위자드
  views/identity_probes/
    show.html.erb
    steps/_s0_loading.html.erb
    ... _s6_final.html.erb

config/initializers/identity_probe.rb  # ENV 키 집중 관리
```

## KPI
- probe 수행률 65% / 정확도 70% / 평균 15s 이하 / 완주자 7일 잔존 1.8×
