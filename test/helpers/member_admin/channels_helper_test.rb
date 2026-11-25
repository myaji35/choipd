require "test_helper"

class MemberAdmin::ChannelsHelperTest < ActionView::TestCase
  test "한국 시간 기준으로 올해 날짜의 연도만 생략한다" do
    travel_to Time.utc(2026, 11, 25, 3) do
      assert_equal "11.22", channel_short_date(Time.utc(2026, 11, 22, 3))
      assert_equal "11.22", channel_short_date(Time.utc(2026, 11, 21, 16))
      assert_equal "2025.12.30", channel_short_date(Time.utc(2025, 12, 30, 3))
      assert_nil channel_short_date(nil)
    end
  end
end
