require "test_helper"

class LegalControllerTest < ActionDispatch::IntegrationTest
  test "privacy policy shows the privacy officer details without placeholders" do
    get privacy_path

    assert_response :ok
    refute_includes response.body, "공개 전 입력 필요"
    assert_includes response.body, "강승식"
    assert_includes response.body, "대표이사"
  end

  test "terms show the business registration number" do
    get terms_path

    assert_includes response.body, "715-86-00843"
  end
end
