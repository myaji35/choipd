require "test_helper"
require "stringio"

class MemberScanOrganizerTest < ActionDispatch::IntegrationTest
  class FakeAi
    attr_reader :tested_key

    def test_connection(api_key)
      @tested_key = api_key
      true
    end
  end

  class FakeCloud
    def create_contact(fields)
      raise "Unexpected contact" unless fields == { names: [ { unstructuredName: "김회원" } ] }

      "people/1"
    end
  end

  setup do
    @original_flag = ENV["IMPD_SCAN_ORGANIZER_ENABLED"]
    @member = create_member("scan-owner")
    sign_in(@member)
    @scan_path = slug_admin_scan_organizer_path(slug: @member.slug)
  end

  teardown do
    ENV["IMPD_SCAN_ORGANIZER_ENABLED"] = @original_flag
  end

  test "disabled feature hides navigation and returns 404 for every action" do
    ENV.delete("IMPD_SCAN_ORGANIZER_ENABLED")
    get slug_admin_dashboard_path(slug: @member.slug)
    assert_response :success
    assert_select "a", text: "스캔 정리", count: 0

    get @scan_path
    assert_response :not_found
    patch @scan_path
    assert_response :not_found
    post test_ai_key_slug_admin_scan_organizer_path(slug: @member.slug)
    assert_response :not_found
    post resolve_slug_admin_scan_item_path(slug: @member.slug, id: 123)
    assert_response :not_found
  end

  test "enabled page stores a key without exposing it in the response or logs" do
    ENV["IMPD_SCAN_ORGANIZER_ENABLED"] = "1"
    log = StringIO.new
    original_logger = Rails.logger
    original_controller_logger = ActionController::Base.logger
    original_record_logger = ActiveRecord::Base.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(log))
    ActionController::Base.logger = Rails.logger
    ActiveRecord::Base.logger = Rails.logger

    get @scan_path
    assert_response :success
    assert_select "a[href=?]", @scan_path, text: "스캔 정리"
    key = "secret-member-api-key-9876"

    patch @scan_path, params: { scan_organizer_setting: { ai_provider: "gemini", ai_api_key: key, scan_folder_name: "스캔" } }
    assert_response :see_other
    refute_includes response.body, key

    follow_redirect!
    assert_response :success
    refute_includes response.body, key
    assert_select "p", text: "••••9876 등록됨"
    assert_select "input[type=password][value='']"
    assert_equal key, @member.reload.scan_organizer_setting.ai_api_key

    patch @scan_path, params: { scan_organizer_setting: { ai_api_key: "", scan_folder_id: "folder-id" } }
    assert_response :see_other
    assert_equal key, @member.reload.scan_organizer_setting.ai_api_key
    refute_includes log.string, key
    assert_includes log.string, "[FILTERED]"
  ensure
    Rails.logger = original_logger
    ActionController::Base.logger = original_controller_logger
    ActiveRecord::Base.logger = original_record_logger
  end

  test "another signed in member cannot view or update the owner's settings" do
    ENV["IMPD_SCAN_ORGANIZER_ENABLED"] = "1"
    sign_in(create_member("scan-other"))

    get @scan_path
    assert_redirected_to login_member_path(slug: @member.slug)
    patch @scan_path, params: { scan_organizer_setting: { scan_folder_id: "other-folder" } }
    assert_redirected_to login_member_path(slug: @member.slug)
    assert_nil @member.reload.scan_organizer_setting
  end

  test "connection test and review use replaceable adapters and member scoped items" do
    ENV["IMPD_SCAN_ORGANIZER_ENABLED"] = "1"
    setting = @member.create_scan_organizer_setting!(ai_provider: "gemini", ai_api_key: "stored-key-1234")
    item = @member.scan_items.create!(source_file_id: "id1", source_name: "명함.png", status: "needs_review", extracted: { category: "business_card", fields: { name: "김회원" } }, failure_reason: "주소록 오류")
    @member.scan_items.create!(source_file_id: "id2", status: "processing")
    other_item = create_member("scan-item-other").scan_items.create!(source_file_id: "id1", status: "needs_review")
    ai = FakeAi.new
    cloud = FakeCloud.new

    with_adapter(:ai_provider_for, ai) do
      post test_ai_key_slug_admin_scan_organizer_path(slug: @member.slug), params: { api_key: "unsaved-key" }
      assert_response :see_other
      assert_equal "stored-key-1234", ai.tested_key
      assert setting.reload.ai_key_verified_at.present?
    end

    get @scan_path
    assert_select "td", text: "확인 필요"
    assert_select "td", text: "주소록 오류"
    assert_select "td", text: "처리 중"
    assert_select "form[action=?]", resolve_slug_admin_scan_item_path(slug: @member.slug, id: item), count: 3

    with_adapter(:cloud_for, cloud) do
      post resolve_slug_admin_scan_item_path(slug: @member.slug, id: other_item), params: { category: "business_card" }
      assert_response :not_found
      post resolve_slug_admin_scan_item_path(slug: @member.slug, id: item), params: { category: "business_card" }
      assert_response :see_other
    end
    assert_equal "processed", item.reload.status
    assert_equal "needs_review", other_item.reload.status
  end

  test "short keys are masked even if an older record has a stored suffix" do
    ENV["IMPD_SCAN_ORGANIZER_ENABLED"] = "1"
    setting = @member.create_scan_organizer_setting!(ai_api_key: "tiny-key")
    setting.update_column(:ai_key_last4, "-key")

    get @scan_path
    assert_response :success
    assert_select "p", text: "••••등록됨"
    assert_select "p", text: /••••-key/, count: 0
    refute_includes response.body, "tiny-key"
  end

  private

  def create_member(slug)
    Member.create!(name: "스캔 회원", email: "#{slug}@example.com", slug: slug, status: "approved", password: "password1234")
  end

  def sign_in(member)
    post login_member_post_path(slug: member.slug), params: { password: "password1234" }
  end

  def with_adapter(name, adapter)
    original = ScanOrganizer.method(name)
    ScanOrganizer.define_singleton_method(name) { |_setting| adapter }
    yield
  ensure
    ScanOrganizer.define_singleton_method(name, original)
  end
end
