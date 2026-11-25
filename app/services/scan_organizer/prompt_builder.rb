module ScanOrganizer
  class PromptBuilder
    def initialize(member:, setting:)
      @member = member
      @setting = setting
    end

    def build
      cloud = Clouds.fetch(@setting.cloud_provider)
      name = single_line(@member.name)
      template = File.read(File.join(__dir__, "prompts", "#{cloud.fetch(:key)}.txt"), encoding: "UTF-8")

      template % {
        member_name: name,
        receipts_sheet_name: single_line(@setting.receipts_sheet_name).presence || "#{name} 영수증",
        documents_folder_name: single_line(@setting.documents_folder_name).presence || "스캔 문서",
        review_folder_name: single_line(@setting.review_folder_name).presence || "스캔 확인 필요",
        frequency: ScanOrganizerSetting::RUN_FREQUENCIES.fetch(@setting.run_frequency)
      }
    end

    private

    def single_line(value)
      value.to_s.gsub(/\R+/, " ").strip.first(80)
    end
  end
end
