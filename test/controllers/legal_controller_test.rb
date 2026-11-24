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

  test "terms have no placeholders and show the full business footer" do
    get terms_path

    assert_response :ok
    refute_includes response.body, "공개 전 입력 필요"
    assert_includes response.body, "대표자 강승식"
    assert_includes response.body, "715-86-00843"
    assert_includes response.body, "남대문로9길 24"
    refute_includes response.body, "715-84"
  end

  test "privacy footer shows the business identity" do
    get privacy_path

    assert_includes response.body, "주식회사 가가호호 AI사업부"
    assert_includes response.body, "715-86-00843"
    assert_includes response.body, "남대문로9길 24"
    refute_includes response.body, "715-84"
  end

  test "privacy officer contact links to the inquiry form" do
    get privacy_path

    assert_select "section:has(#article-15)" do |sections|
      assert_select "a[href=?]", new_inquiry_path, minimum: 1
      refute_match(/[\w.+-]+@[\w-]+\.[\w.]+/, sections.first.text)
    end
  end

  test "privacy lists the four remedy agencies" do
    get privacy_path

    %w[1833-6972 118 1301 182 kopico.go.kr privacy.kisa.or.kr].each do |contact|
      assert_includes response.body, contact
    end
  end
end
