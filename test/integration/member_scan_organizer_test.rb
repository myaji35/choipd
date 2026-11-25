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
  end

  test "shows Gemini instructions and the saved organization prompt" do
    ENV["IMPD_SCAN_ORGANIZER_ENABLED"] = "1"
    patch @scan_path, params: { scan_organizer_setting: {
      cloud_provider: "google_drive", receipts_sheet_name: "경비 장부", documents_folder_name: "자료실",
      review_folder_name: "검토함", run_frequency: "weekly"
    } }
    assert_response :see_other

    follow_redirect!
    assert_response :success
    assert_select "option[value=google_drive][selected]", text: /구글 드라이브.*Gemini/
    assert_select "option[value=onedrive][disabled]", text: /원드라이브.*준비 중/
    assert_select "h2", text: "Gemini 주기 실행 안내"
    assert_select "ol li", text: /예약된 작업.*매주/
    assert_select "textarea[readonly]", text: /#{@member.name}.*매주.*경비 장부.*자료실.*검토함/m
    assert_select "button[type=button]", text: "프롬프트 복사"

    patch @scan_path, params: { scan_organizer_setting: { cloud_provider: "onedrive", run_frequency: "daily" } }
    assert_response :see_other
    follow_redirect!
    assert_includes response.body, "스캔 설정을 저장하지 못했습니다"
    setting = @member.reload.scan_organizer_setting
    assert_equal "google_drive", setting.cloud_provider
    assert_equal "weekly", setting.run_frequency
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

    patch @scan_path, params: { scan_organizer_setting: { ai_provider: "gemini", ai_api_key: key, documents_folder_name: "스캔" } }
    assert_response :see_other
    refute_includes response.body, key

    follow_redirect!
    assert_response :success
    refute_includes response.body, key
    assert_select "p", text: "••••9876 등록됨"
    assert_select "input[type=password][value='']"
    assert_equal key, @member.reload.scan_organizer_setting.ai_api_key

    patch @scan_path, params: { scan_organizer_setting: { ai_api_key: "", documents_folder_name: "folder-id" } }
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
    patch @scan_path, params: { scan_organizer_setting: { documents_folder_name: "other-folder" } }
    assert_redirected_to login_member_path(slug: @member.slug)
    post test_ai_key_slug_admin_scan_organizer_path(slug: @member.slug)
    assert_redirected_to login_member_path(slug: @member.slug)
    assert_nil @member.reload.scan_organizer_setting
  end

  test "connection test uses the saved key" do
    ENV["IMPD_SCAN_ORGANIZER_ENABLED"] = "1"
    setting = @member.create_scan_organizer_setting!(ai_provider: "gemini", ai_api_key: "stored-key-1234")
    ai = FakeAi.new

    with_adapter(:ai_provider_for, ai) do
      post test_ai_key_slug_admin_scan_organizer_path(slug: @member.slug), params: { api_key: "unsaved-key" }
      assert_response :see_other
      assert_equal "stored-key-1234", ai.tested_key
      assert setting.reload.ai_key_verified_at.present?
    end
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
