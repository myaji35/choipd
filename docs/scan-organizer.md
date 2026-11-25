# 스캔 정리 1차

회원이 구글 드라이브 스캔 폴더에 올린 이미지를 회원 본인의 Gemini, OpenAI 또는 Anthropic 키로 분류합니다. `IMPD_SCAN_ORGANIZER_ENABLED=1`이면 회원 관리자 메뉴의 **업무 → 스캔 정리**에서 폴더와 AI 키를 등록하고 처리 내역을 볼 수 있습니다. 스위치는 기본으로 꺼져 있습니다.

## 처리 흐름

1. 구글 드라이브 어댑터가 스캔 폴더 바로 아래의 이미지 목록을 읽습니다. 처리기는 회원과 드라이브 파일 ID를 기준으로 항목을 찾아 완료 및 확인 대기 항목의 중복 처리를 건너뜁니다.
2. 처리기가 원본 이미지를 내려받아 회원이 선택한 AI 제공자에 전송합니다. 분류 신뢰도가 0.75 미만이거나 알려진 분류가 아니면 추출 결과를 저장하고 **확인 필요**로 표시합니다. 회원은 처리 내역에서 분류를 선택해 저장을 실행할 수 있습니다.
3. 명함은 Google People API를 통해 회원 주소록에 연락처를 생성합니다. 영수증은 스캔 폴더의 앱 전용 **영수증** 스프레드시트에 날짜, 가맹점, 합계, 부가세, 결제수단, 원본 파일명 순으로 추가합니다. 문서는 스캔 폴더 아래 `문서/<문서 유형>`에 이동하고 날짜와 제목으로 이름을 변경합니다. 날짜를 알 수 없으면 처리일을 사용합니다.
4. 완료 시 결과 위치와 처리 시각을, 실패 시 자격 증명을 치환한 실패 사유를 기록합니다. 외부 쓰기 요청 직후 통신이 끊기면 결과가 불확실할 수 있으므로 재처리 전에 주소록이나 시트를 확인합니다.

[People API 연락처 생성](https://developers.google.com/people/api/rest/v1/people/createContact) · [Sheets API 행 추가](https://developers.google.com/workspace/sheets/api/reference/rest/v4/spreadsheets.values/append) · [Drive 폴더 및 파일 이동](https://developers.google.com/workspace/drive/api/guides/folder)

## 구글 권한 범위

- `drive.file`을 우선 사용합니다. 앱이 생성했거나 회원이 Picker로 고른 파일에 접근하고 이동 및 이름 변경에 사용합니다.
- `contacts`는 Google People API로 주소록에 연락처를 생성하는 데 사용합니다.
- `spreadsheets`는 Google Sheets에 영수증 데이터를 추가하는 데 사용합니다.

스캐너 앱이 업로드한 파일은 `drive.file`만으로 목록 조회나 다운로드가 제한될 수 있습니다. Picker로 폴더와 필요한 파일을 회원이 직접 고르게 한 뒤, 새로 올라오는 파일의 조회 및 다운로드 가능 여부를 확인해야 합니다. Picker로 권한을 부여하는 흐름으로도 자동 수집이 불가능하면 읽기에 제한 권한인 `drive.readonly`가 필요하며 Google 앱 검수를 거쳐야 합니다. 파일 이동과 이름 변경에는 별도의 쓰기 권한이 필요하므로 대상 파일에 대해 Picker와 `drive.file`로 쓰기 가능 여부를 검증합니다. [Google Drive 권한 범위](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)

## 운영에서 켜기 전 대표님 확인 항목

- Google 동의 화면 및 요청 권한을 검토하고 필요한 앱 검수를 완료합니다. 운영 OAuth 클라이언트의 `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`을 주입합니다.
- 개인정보처리방침에 명함 연락처, 영수증 데이터, 스캔 이미지의 수집 항목과 목적, 보관 기간 및 삭제 절차를 반영합니다. 스캔 이미지가 회원이 선택한 AI 제공자에게 전송되는 점을 안내합니다.
- AI 키의 보관 기간, 교체 및 삭제 정책을 승인합니다. 운영 환경에 `AR_ENCRYPTION_PRIMARY_KEY`, `AR_ENCRYPTION_DETERMINISTIC_KEY`, `AR_ENCRYPTION_SALT`를 주입합니다. AI 키와 구글 갱신 토큰은 DB에 암호화해 보관합니다.
- 세 제공자 모델 이름을 확인합니다. 필요하면 `SCAN_ORGANIZER_GEMINI_MODEL`, `SCAN_ORGANIZER_OPENAI_MODEL`, `SCAN_ORGANIZER_ANTHROPIC_MODEL`로 지정합니다.
- Drive 폴더·시트의 find_or_create가 동시에 실행되면 중복 생성될 수 있으므로 주기 처리 잡은 회원당 1개만 실행되도록 합니다.
- 운영 승인 후 `IMPD_SCAN_ORGANIZER_ENABLED=1`을 설정합니다.

## 다음 단계

구글 OAuth 연결 화면과 동의 왕복, 폴더 및 파일 선택용 Picker, 주기 처리 잡, 원드라이브 어댑터를 추가합니다. 주기 처리 잡은 처리 도중 프로세스가 끊겨 `processing`(처리 중)으로 오래 남은 항목을 일정 시간 뒤 `failed`로 되돌려 다시 처리되게 해야 합니다(1차에는 잡이 없어 해당 경로 없음). 1차 화면은 구글 드라이브 연결이 운영 승인 후 열린다고 안내합니다.

AI 이미지 요청 형식은 각 제공자의 API 문서를 따릅니다. [Gemini 모델](https://aistudio.google.com/docs/models/gemini-3.5-flash-lite) · [OpenAI 이미지 입력](https://developers.openai.com/api/docs/guides/images-vision) · [Anthropic 이미지 입력](https://platform.claude.com/docs/en/build-with-claude/vision)
