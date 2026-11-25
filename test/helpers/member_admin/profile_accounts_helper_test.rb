require "test_helper"

class MemberAdmin::ProfileAccountsHelperTest < ActionView::TestCase
  test "경과 시간을 한국어로 표시한다" do
    freeze_time do
      assert_equal "방금 전", korean_time_ago(30.seconds.ago)
      assert_equal "5분 전", korean_time_ago(5.minutes.ago)
      assert_equal "3시간 전", korean_time_ago(3.hours.ago)
      assert_equal "2일 전", korean_time_ago(2.days.ago)
      assert_equal "1개월 전", korean_time_ago(45.days.ago)
      assert_equal "1년 전", korean_time_ago(400.days.ago)
    end
  end

  test "이메일은 로컬 부분을 가리고 도메인을 유지한다" do
    assert_equal "ka***@example.com", masked_login_id("kangss@example.com")
  end

  test "일반 아이디는 앞 두 글자만 표시한다" do
    assert_equal "강민***", masked_login_id("강민테스트")
  end

  test "빈 아이디에는 마스킹 결과가 없다" do
    [ nil, "", "  " ].each do |value|
      assert_nil masked_login_id(value)
    end
  end
end
