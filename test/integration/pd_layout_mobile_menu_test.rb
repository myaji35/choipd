require "test_helper"

class PdLayoutMobileMenuTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "휴대폰에서 PD 메뉴는 처음에 닫혀 있고 본문은 전체 너비를 사용한다" do
    sign_in AdminUser.create!(email: "pd-mobile-menu@example.test", password: "password123", role: "pd")
    get pd_profile_accounts_path
    assert_response :success

    assert_select 'button.pd-menu-button[aria-controls="pd-navigation"][aria-expanded="false"]' do |buttons|
      assert_includes buttons.first["data-action"].to_s, "impd-nav#toggle"
    end
    assert_select "aside#pd-navigation[data-pd-menu]"
    assert_select "aside#pd-navigation a[href=?]", pd_members_path, text: "회원 대행 등록", count: 1
    assert_select 'aside#pd-navigation button.pd-menu-close[aria-label="메뉴 닫기"][data-action="impd-nav#close"]'
    assert_select ".pd-backdrop[hidden]"

    assert_select ".pd-mobile-links a.text-gray-500[href=?][target='_blank'][rel='noopener']", root_path, count: 1 do
      assert_select "i.lni.lni-globe-1", count: 1
      assert_select "span", text: "공개 사이트 보기"
    end
    assert_select "a[href=?]", admin_root_path, count: 0

    assert_includes response.body, "@media (max-width: 767px)"
    assert_includes response.body, "[data-pd-menu] { transform: translateX(-100%)"
    assert_includes response.body, ".pd-main.ml-60 { margin-left: 0; }"
  end

  test "운영자가 PD 화면을 보면 Admin 링크가 표시된다" do
    sign_in AdminUser.create!(email: "admin-mobile-menu@example.test", password: "password123", role: "admin")
    get pd_root_path
    assert_response :success

    assert_select ".pd-header-links a[href=?]", admin_root_path, text: "Admin", count: 1
    assert_select ".pd-mobile-links a.text-gray-500[href=?]", admin_root_path, count: 1 do
      assert_select "i.lni.lni-shield-2", count: 1
      assert_select "span", text: "Admin"
    end
  end
end
