# imPD UI/UX 기획안 명세서
> Phase 3 Mockup — 2025-2026 트렌드 적용

## 1. 디자인 시스템

### 컬러 팔레트
| Token | HEX | 용도 |
|-------|-----|------|
| Navy | `#1a2744` | 주 배경, 헤더, 텍스트 |
| Navy Light | `#243560` | 보조 배경 |
| Coral | `#ff6b47` | CTA 버튼, 강조 |
| Coral Light | `#ff8f72` | Hover, 하이라이트 |
| Warm White | `#faf9f7` | 메인 배경 |

### 타이포그래피
- **헤딩**: Noto Serif KR (serif 감성, 신뢰/전문성)
- **본문**: Noto Sans KR (가독성)
- **Hero 텍스트**: `clamp(2rem, 5vw, 3.5rem)` 반응형

### 트렌드 적용 요소
| 트렌드 | 적용 위치 |
|--------|----------|
| **Bento Grid** | 홈 서비스 허브 섹션 |
| **Glassmorphism** | Hero 프로필 카드, 로그인 폼 |
| **Gradient Mesh** | Hero 배경, CTA 섹션 |
| **Micro-interactions** | 버튼 hover/active 효과 |
| **Scroll Reveal** | 모든 섹션 등장 애니메이션 |
| **Frosted Glass Nav** | 상단 네비게이션 blur 처리 |

## 2. 페이지별 명세

### 홈 (index.html)
- **Hero**: 네이비 배경 + Gradient Mesh + 글래스 프로필 카드
- **서비스 허브**: 12열 Bento Grid (교육 2x2, 미디어/작품/커뮤니티 2x1)
- **강좌 카드**: Auto-fill Grid (min 300px)
- **CTA**: 네이비 배경 + Coral accent
- **문의 폼**: 2열 레이아웃

### 교육 (education.html)
- **필터**: Pill 버튼 (전체/온라인/오프라인/B2B)
- **강좌 그리드**: 3열 카드 + 타입별 배지
- **B2B 문의**: 네이비 배경 + 장점 리스트 + 폼

### 관리자 로그인 (admin-login.html)
- **배경**: 풀스크린 네이비 + 별 트윙클 애니메이션
- **로그인 카드**: Glassmorphism 카드
- **역할 탭**: 어드민/PD 전환 탭
- **인터랙션**: 로딩 스피너, 에러 메시지 애니메이션

### 어드민 대시보드 (admin-dashboard.html)
- **레이아웃**: 240px 사이드바 + 메인 콘텐츠
- **KPI**: 4개 카드 (유통사, 결제, 문의, 뉴스레터)
- **차트**: 바 차트 시뮬레이션 (CSS only)
- **활동 피드**: 실시간 이벤트 스트림
- **테이블**: 유통사 신청 상태 관리

## 3. 컴포넌트 → Rails ERB 매핑

| Mockup 컴포넌트 | Rails View | 비고 |
|----------------|-----------|------|
| `.nav` | `layouts/chopd/_header.html.erb` | Stimulus scroll 처리 |
| `.hero` | `chopd/home/index.html.erb` | Stimulus slideshow |
| `.bento-grid` | `chopd/home/_service_hub.html.erb` | 정적 파셜 |
| `.card.course-card` | `chopd/education/_course_card.html.erb` | DB 데이터 연동 |
| `.filter-btn` | Stimulus filter controller | JS 필터링 |
| `.admin-layout` | `layouts/admin.html.erb` | 사이드바 분리 |
| `.kpi-card` | `admin/dashboard/_kpi_cards.html.erb` | 실시간 카운트 |
| `.card--glass` | 로그인 폼 | Glassmorphism |

## 4. Stimulus 컨트롤러 목록 (구현 예정)

```javascript
// app/javascript/controllers/
├── slideshow_controller.js   // Hero 슬라이드쇼
├── scroll_reveal_controller.js // 스크롤 애니메이션
├── course_filter_controller.js // 강좌 필터링
├── nav_blur_controller.js    // 스크롤시 nav blur
└── form_submit_controller.js // Turbo Stream 폼 제출
```

## 5. 반응형 브레이크포인트

| 브레이크포인트 | 적용 사항 |
|-------------|---------|
| `< 768px` | Bento Grid → 1열, Nav → 햄버거 |
| `< 480px` | Hero 버튼 → 세로 정렬 |
| `> 1200px` | 최대 너비 1200px 고정 |

## 6. 접근성 고려사항 (WCAG 2.1)

- 색상 대비: Navy/White = 8.5:1 ✅
- 포커스 스타일: 모든 인터랙티브 요소
- ARIA 레이블: 아이콘 전용 버튼
- 시멘틱 HTML: header, nav, main, footer, section, article
