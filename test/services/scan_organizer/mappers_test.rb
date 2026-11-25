require "test_helper"

class ScanOrganizer::MappersTest < ActiveSupport::TestCase
  test "cleans document names and preserves extensions within 80 characters" do
    target = ScanOrganizer::Mappers.document_target({
      date: "2026-11-25", title: %q(계/약\서:*?"<>|) + "가" * 100, doc_type: "../"
    }, "original.PNG")

    assert_equal "문서/기타", target[:folder_path]
    assert_equal "2026-11-25_계약서#{"가" * 62}.PNG", target[:new_name]
    assert_equal 80, target[:new_name].length
  end

  test "maps a receipt to a six-column row in spreadsheet order" do
    fields = { "date" => "2026-11-25", "merchant" => "가게", "total" => 11000, "vat" => 1000, "payment_method" => "카드", "items" => [] }

    assert_equal [ "2026-11-25", "가게", 11000, 1000, "카드", "receipt.png" ],
      ScanOrganizer::Mappers.receipt_row(fields, "receipt.png")
  end
end
