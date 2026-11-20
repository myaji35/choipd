require "test_helper"

class BrandOpsChartHelperTest < ActionView::TestCase
  test "chooses the next useful maximum tick" do
    assert_equal 25, ops_nice_max(23)
    assert_equal 120, ops_nice_max(105)
    assert_equal 10, ops_nice_max(9)
  end
end
