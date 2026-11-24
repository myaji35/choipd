# 법적 고지(이용약관·개인정보처리방침) 공개 규칙 — ISS-490

출처 카드: ISS-480(운영 /terms·/privacy 에 자리표시 5개가 공개되고 사업자등록번호가 715-84 로 잘못 적힌 문제). 이 문서는 그 화면들이 **늘 지켜야 할 규칙**과 그 규칙을 지키는 **시험**을 짝지어 둔다. 문구를 고칠 때 이 표의 시험이 깨지면 규칙을 어긴 것이다.

## 확정값 (2026-11-20 대표님 컨펌, ISS-480)
| 항목 | 값 | 근거 |
|---|---|---|
| 상호 | 주식회사 가가호호 AI사업부 | 09-Paperclip/CLO 가가호호 기본정보 |
| 대표자 | 강승식 | 같은 곳 |
| 사업자등록번호 | 715-86-00843 (715-84 는 오기) | 같은 곳 |
| 본점 | 서울특별시 중구 남대문로9길 24, 10층(다동) | 같은 곳 |
| 개인정보 보호책임자 | 강승식 · 대표이사 | 컨펌 imPD_개인정보보호책임자 (2026-11-20) |
| 보호책임자 공개 연락처 | **미정** — ISS-485 대표님 값 대기. 그때까지 '문의하기'(/inquiries/new) 로 연결 | ISS-485 |

## 규칙
| # | 규칙 | 근거 법령 | 적용 화면 |
|---|---|---|---|
| R1 | 공개 화면에 '공개 전 입력 필요' 같은 자리표시 문구가 하나도 없어야 한다 | — (운영 품질) | /privacy, /terms |
| R2 | 개인정보 보호책임자의 성명·직책을 적는다 | 개인정보 보호법 제30조 제1항 제7호, 시행령 제31조 | /privacy 제15조 |
| R3 | 보호책임자에게 닿는 연락 수단(전화·전자우편·문의 창구 중 하나 이상)을 적는다. 값이 정해지기 전에는 지어낸 이메일을 쓰지 않고 문의하기로 연결한다 | 같은 조 | /privacy 제15조 |
| R4 | 화면 하단에 상호·대표자·사업자등록번호·주소를 적는다 | 전자상거래법 제10조(사이버몰 운영자 표시) | /privacy, /terms 하단 |
| R5 | 사업자등록번호는 715-86-00843 하나뿐이다. 715-84 가 다시 나오면 안 된다 | ISS-480 오기 사고 | /privacy, /terms |
| R6 | 권익침해 구제 기관 4곳(분쟁조정위·KISA 118·대검 1301·경찰 182)을 안내한다 | 개인정보 보호법 제30조 제1항 | /privacy 제16조 |
| R7 | 시행일·공고일을 적는다 | 개인정보 보호법 시행령 제31조 | /privacy 제17조, /terms 부칙 |

## 시나리오 (역할: 방문자 — 로그인 없이 누구나 본다)
1. 방문자가 /privacy 를 연다 → 200, 자리표시 없음, 제15조에 강승식·대표이사, 연락 수단 링크가 있다.
2. 방문자가 /terms 를 연다 → 200, 자리표시 없음, 하단에 대표자·715-86-00843·본점 주소.
3. 방문자가 보호책임자에게 연락하려 한다 → 제15조 연락처 칸의 '문의하기'를 누르면 문의 작성 화면(/inquiries/new)이 열린다.
4. 누군가 문구를 고치다 715-84 로 되돌린다 → 시험이 실패해 출고가 막힌다.

## 규칙 ↔ 시험 대응표
시험 파일: `test/controllers/legal_controller_test.rb`

| 규칙 | 시험 | 상태 |
|---|---|---|
| R1 (/privacy) | privacy policy shows the privacy officer details without placeholders | 있음 |
| R1 (/terms) | terms have no placeholders and show the full business footer | ISS-490 에서 추가 |
| R2 | privacy policy shows the privacy officer details without placeholders | 있음 |
| R3 | privacy officer contact links to the inquiry form | ISS-490 에서 추가 |
| R4 (/terms) | terms have no placeholders and show the full business footer | ISS-490 에서 추가 |
| R4 (/privacy) | privacy footer shows the business identity | ISS-490 에서 추가 |
| R5 | terms·privacy 시험에서 715-84 부재 확인 | ISS-490 에서 추가 |
| R6 | privacy lists the four remedy agencies | ISS-490 에서 추가 |
| R7 | (문구 고정값 — 바뀔 때마다 날짜가 달라지므로 시험하지 않음, 변경 시 이 문서 갱신) | 범위 밖 |

## 남은 일
- ISS-485: 보호책임자 공개 연락처 값(대표님). 값이 오면 R3 시험의 기대값을 그 값으로 바꾼다.
