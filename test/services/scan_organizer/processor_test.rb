require "test_helper"
require "stringio"

class ScanOrganizer::ProcessorTest < ActiveSupport::TestCase
  KEY = "test-ai-secret-1234"
  TOKEN = "test-cloud-secret-4321"

  class FakeCloud
    attr_reader :writes, :downloads
    attr_accessor :on_download, :on_write

    def initialize
      @writes = []
      @downloads = []
    end

    def download(file_id)
      @downloads << file_id
      on_download&.call
      Rails.root.join("test/fixtures/files/scan", file_id).binread
    end

    def create_contact(fields)
      on_write&.call
      @writes << [ :contact, fields ]
      "people/1"
    end

    def append_receipt_row(row)
      on_write&.call
      @writes << [ :receipt, row ]
      "영수증!A1:F1"
    end

    def move_and_rename(file_id:, folder_path:, new_name:)
      on_write&.call
      @writes << [ :document, file_id, folder_path, new_name ]
      "#{folder_path}/#{new_name}"
    end
  end

  class FakeAi
    attr_accessor :confidence, :error, :category_override, :on_classify

    def initialize
      @confidence = 0.95
    end

    def classify(api_key:, image_bytes:, mime_type:)
      on_classify&.call
      raise error if error
      raise "Unexpected AI input" unless api_key == KEY && mime_type == "image/png"

      category, fields = {
        "business_card" => { name: "김회원", company: "회사", title: "대표", phones: [ "010-1111-2222" ], emails: [ "scan@example.com" ], address: "서울" },
        "receipt" => { date: "2026-11-25", merchant: "가게", total: 11000, vat: 1000, payment_method: "카드" },
        "document" => { date: "2026-11-25", title: "거래 명세서", doc_type: "거래" }
      }.find do |name, _|
        Rails.root.join("test/fixtures/files/scan", "#{name}.png").binread == image_bytes
      end

      { category: category_override || category, confidence: confidence, fields: fields }
    end
  end

  setup do
    @member = Member.create!(name: "스캔 회원", email: "scans@example.com", slug: "scan-worker", password: "password1234")
    @member.create_scan_organizer_setting!(ai_provider: "gemini", ai_api_key: KEY, cloud_refresh_token: TOKEN)
    @ai = FakeAi.new
    @cloud = FakeCloud.new
    @processor = ScanOrganizer::Processor.new(member: @member, ai: @ai, cloud: @cloud)
  end

  test "processes each category with the mapped destination data once" do
    %w[business_card receipt document].each do |category|
      item = process(category).reload
      assert_equal "processed", item.status
      assert_equal category, item.category
      assert item.result_location.present?
      assert item.processed_at.present?
      assert_equal item.id, process(category).id
    end

    assert_equal [
      [ :contact, {
        names: [ { unstructuredName: "김회원" } ], organizations: [ { name: "회사", title: "대표" } ],
        phoneNumbers: [ { value: "010-1111-2222" } ], emailAddresses: [ { value: "scan@example.com" } ],
        addresses: [ { streetAddress: "서울" } ]
      } ],
      [ :receipt, [ "2026-11-25", "가게", 11000, 1000, "카드", "receipt.png" ] ],
      [ :document, "document.png", "문서/거래", "2026-11-25_거래 명세서.png" ]
    ], @cloud.writes
  end

  test "keeps low confidence and unknown categories for review without writing externally" do
    @ai.confidence = 0.5
    receipt = process("receipt").reload
    assert_equal "needs_review", receipt.status
    assert_equal "가게", receipt.extracted.dig("fields", "merchant")
    assert_equal 0.5, receipt.confidence

    @ai.confidence = 0.95
    @ai.category_override = "other"
    document = process("document").reload
    assert_equal "needs_review", document.status
    assert_nil document.category
    assert_equal "other", document.extracted["category"]
    assert_empty @cloud.writes
  end

  test "redacts both secrets and limits recorded failures" do
    @ai.error = ScanOrganizer::Http::Error.new("#{KEY} #{TOKEN} #{"오" * 300}")
    item = process("document").reload

    assert_equal "failed", item.status
    assert_match(/\A\[FILTERED\] \[FILTERED\]/, item.failure_reason)
    assert_equal 200, item.failure_reason.length
    assert_empty @cloud.writes
  end

  test "manual resolution uses saved fields and writes only once" do
    @ai.confidence = 0.5
    item = process("receipt")
    @ai.error = "Must not classify again"

    @processor.resolve!(item, "receipt")
    @processor.resolve!(item, "receipt")

    assert_equal "processed", item.reload.status
    assert_equal "receipt", item.category
    assert_equal [ [ :receipt, [ "2026-11-25", "가게", 11000, 1000, "카드", "receipt.png" ] ] ], @cloud.writes
  end

  test "claims before external calls without opening a transaction around them" do
    baseline = ScanItem.connection.open_transactions
    check_claim = lambda do
      assert_equal baseline, ScanItem.connection.open_transactions
      assert_equal "processing", @member.scan_items.find_by!(source_file_id: "receipt.png").status
    end
    @cloud.on_download = lambda do
      check_claim.call
      assert_equal "processing", process("receipt").status
    end
    @ai.on_classify = check_claim
    @cloud.on_write = check_claim
    assert_equal "processed", process("receipt").status
    assert_equal [ "receipt.png" ], @cloud.downloads
    assert_equal 1, @cloud.writes.size

    @ai.confidence = 0.5
    @cloud.on_download = @ai.on_classify = nil
    item = process("business_card")
    stale = ScanItem.find(item.id)
    @cloud.on_write = lambda do
      assert_equal baseline, ScanItem.connection.open_transactions
      assert_equal "processing", item.reload.status
      assert_equal "processing", @processor.resolve!(stale, "business_card").status
    end
    assert_equal "processed", @processor.resolve!(item, "business_card").status
    assert_equal 2, @cloud.writes.size
  end

  test "finds the winner after a unique index collision" do
    existing = @member.scan_items.create!(source_file_id: "document.png", source_name: "원본.png", mime_type: "image/png")
    @member.scan_items.define_singleton_method(:find_or_create_by!) do |**|
      raise ActiveRecord::RecordNotUnique
    end

    item = process("document")
    assert_equal existing.id, item.id
    assert_equal "원본.png", item.source_name
    assert_equal "processed", item.status
  end

  test "fails before download when the setting or key is missing and retries failed items" do
    setting = @member.scan_organizer_setting
    setting.destroy!
    @member.reload
    item = process("receipt")
    assert_equal "failed", item.status
    assert_equal "스캔 설정과 AI 키를 먼저 등록해 주세요.", item.failure_reason

    setting = @member.create_scan_organizer_setting!
    assert_equal item.failure_reason, process("receipt").failure_reason
    assert_empty @cloud.downloads

    setting.update!(ai_api_key: KEY)
    assert_equal "processed", process("receipt").status
  end

  test "unexpected failures discard unsaved extraction and log only the exception class" do
    log = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)
    @cloud.on_write = -> { raise ArgumentError, "#{KEY} #{TOKEN} private message" }

    item = process("receipt").reload
    assert_equal "failed", item.status
    assert_equal "처리 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.", item.failure_reason
    assert_empty item.extracted
    assert_nil item.category
    assert_nil item.confidence
    assert_equal "ScanOrganizer::Processor ArgumentError", log.string.strip
  ensure
    Rails.logger = original_logger
  end

  test "review failures preserve extraction and allow another selection" do
    @ai.confidence = 0.5
    item = process("receipt")
    @cloud.on_write = -> { raise ScanOrganizer::Http::Error, "시트 오류" }
    assert_equal "needs_review", @processor.resolve!(item, "receipt").status
    assert_equal "시트 오류", item.failure_reason
    assert_equal "가게", item.extracted.dig("fields", "merchant")

    @member.scan_organizer_setting.destroy!
    @member.reload
    assert_equal "needs_review", @processor.resolve!(item, "receipt").status
    assert_equal "스캔 설정을 먼저 저장해 주세요.", item.failure_reason

    @member.create_scan_organizer_setting!(ai_api_key: KEY)
    @cloud.on_write = nil
    assert_equal "processed", @processor.resolve!(item, "receipt").status
    assert_nil item.failure_reason
    assert_equal 1, @cloud.writes.size
  end

  test "review rejects mismatched classifications and mappings without essential fields" do
    item = @member.scan_items.create!(source_file_id: "review.png", source_name: "원본.png", status: "needs_review")
    [
      [ "business_card", "document", { name: "김회원" } ],
      [ "receipt", "document", { merchant: "가게" } ],
      [ "business_card", "business_card", { company: "회사", address: "서울", phones: [ "" ] } ],
      [ "receipt", "receipt", { date: "", vat: 1000, payment_method: "카드" } ]
    ].each do |selected, extracted_category, fields|
      item.update!(category: selected, extracted: { category: extracted_category, fields: fields })
      @processor.resolve!(item, selected)
      assert_equal "needs_review", item.reload.status
      assert_equal "선택한 분류로 읽을 정보가 부족합니다. 원본을 직접 정리해 주세요.", item.failure_reason
    end
    assert_empty @cloud.writes

    @processor.resolve!(item, "document")
    assert_equal "processed", item.reload.status
    assert_equal [ [ :document, "review.png", "문서/기타", "#{Date.current.iso8601}_원본.png" ] ], @cloud.writes
  end

  test "inspection shows only the member id" do
    assert_equal "#<ScanOrganizer::Processor member_id=#{@member.id}>", @processor.inspect
  end

  private

  def process(category)
    name = "#{category}.png"
    @processor.process(id: name, name: name, mime_type: "image/png")
  end
end
