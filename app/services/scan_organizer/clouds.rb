module ScanOrganizer
  module Clouds
    ALL = [
      {
        key: "google_drive",
        label: "구글 드라이브",
        ai_label: "Gemini",
        available: true,
        instructions: [
          "Gemini 앱(gemini.google.com)을 열고 Google Workspace(드라이브·Gmail 등) 연결이 허용되어 있는지 확인하세요.",
          "정리 프롬프트를 복사해 붙여 넣고 한 번 실행한 뒤 결과 표를 확인하세요.",
          "결과가 맞으면 Gemini의 ‘예약된 작업’에 같은 프롬프트를 등록하고 설정한 주기(%{frequency})로 실행하세요.",
          "예약 기능이나 일부 작업(주소록 추가·파일 이동)이 계정에서 지원되지 않으면 필요할 때 프롬프트를 실행하고, 결과 표에서 ‘직접 반영 필요’로 표시된 항목만 손으로 반영하세요."
        ].freeze
      }.freeze,
      { key: "onedrive", label: "원드라이브", ai_label: "Microsoft Copilot", available: false }.freeze
    ].freeze

    def self.available_keys
      ALL.select { |cloud| cloud.fetch(:available) }.pluck(:key)
    end

    def self.fetch(key)
      ALL.find { |cloud| cloud.fetch(:key) == key } || raise(KeyError, "지원하지 않는 클라우드입니다.")
    end
  end
end
