require "test_helper"

class ChopdHeaderIconsTest < ActionDispatch::IntegrationTest
  test "the imPD homepage does not render the chopd header" do
    get root_path
    assert_response :ok
    assert_select "header#nav", count: 0
  end

  test "the education header uses decorative Lineicons for inquiry and mobile menu" do
    get education_path
    assert_response :ok

    assert_select "header#nav", count: 1 do
      assert_select "svg", count: 0
      assert_select '.nav-cta i.lni.lni-chat-bubble-2[aria-hidden="true"]', count: 1
      assert_select 'button.nav-mobile-btn[aria-label="메뉴"] i.lni.lni-menu-hamburger-1[aria-hidden="true"]', count: 1
    end
  end
end
