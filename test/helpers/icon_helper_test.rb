require "test_helper"

class IconHelperTest < ActionView::TestCase
  test "renders a decorative icon with classes and size" do
    assert_dom_equal '<i class="lni lni-check extra" style="color: red; font-size: 16px" aria-hidden="true"></i>', lni_icon("check", size: 16, class: "extra", style: "color: red")
  end

  test "renders an accessible label" do
    assert_dom_equal '<i class="lni lni-check" aria-hidden="false" role="img" aria-label="완료"></i>', lni_icon("check", label: "완료")
  end

  test "rejects unknown names" do
    assert_raises(ArgumentError) { lni_icon("not-an-icon") }
  end
end
