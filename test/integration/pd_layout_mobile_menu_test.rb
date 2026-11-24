require "test_helper"

class PdLayoutMobileMenuTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in AdminUser.create!(email: "pd-mobile-menu@example.test", password: "password123", role: "pd")
  end

  test "휴대폰에서 PD 메뉴는 처음에 닫혀 있고 본문은 전체 너비를 사용한다" do
    get pd_profile_accounts_path
    assert_response :success

    assert_select 'button.pd-menu-button[aria-controls="pd-navigation"][aria-expanded="false"]' do |buttons|
      assert_includes buttons.first["data-action"].to_s, "impd-nav#toggle"
    end
    assert_select "aside#pd-navigation[data-pd-menu]"
    assert_select 'aside#pd-navigation button.pd-menu-close[aria-label="메뉴 닫기"][data-action="impd-nav#close"]'
    assert_select ".pd-backdrop[hidden]"

    assert_includes response.body, "@media (max-width: 767px)"
    assert_includes response.body, "[data-pd-menu] { transform: translateX(-100%)"
    assert_includes response.body, ".pd-main.ml-60 { margin-left: 0; }"
  end
end
