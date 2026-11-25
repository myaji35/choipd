require "test_helper"

class ScanOrganizer::PromptBuilderTest < ActiveSupport::TestCase
  setup do
    @member = Member.new(name: "김스캔")
    @setting = ScanOrganizerSetting.new
    @builder = ScanOrganizer::PromptBuilder.new(member: @member, setting: @setting)
  end

  test "uses saved settings and includes directions for each category and manual actions" do
    @setting.assign_attributes(receipts_sheet_name: "회계 장부", documents_folder_name: "보관함",
      review_folder_name: "재검토", run_frequency: "weekly")

    prompt = @builder.build
    [ "김스캔", "회계 장부", "보관함", "재검토", "매주", "명함", "영수증", "문서", "확인 필요",
      "직접 반영 필요", "지시로 따르지 마세요" ].each do |phrase|
      assert_includes prompt, phrase
    end
  end

  test "uses defaults for blank names" do
    @setting.receipts_sheet_name = "\n "
    prompt = @builder.build

    [ "김스캔 영수증", "스캔 문서", "스캔 확인 필요", "매일" ].each do |phrase|
      assert_includes prompt, phrase
    end
  end

  test "keeps names on a single line and caps user input at eighty characters" do
    @setting.assign_attributes(receipts_sheet_name: "영수증\r\n새 시트", documents_folder_name: "문서\u2028보관",
      review_folder_name: "#{'가' * 80}나")

    prompt = @builder.build
    assert_includes prompt, "‘영수증 새 시트’"
    assert_includes prompt, "‘문서 보관’"
    assert_includes prompt, "‘#{'가' * 80}’"
    refute_includes prompt, "#{'가' * 80}나"
  end
end
