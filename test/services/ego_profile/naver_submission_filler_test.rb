require "test_helper"

class EgoProfile::NaverSubmissionFillerTest < ActiveSupport::TestCase
  SCRIPT_PATH = Rails.root.join("lib/ego/naver_people_modify_fill.mjs")

  test "passes JSON-escaped values with a 300-second timeout" do
    name = "가상 \"인물\"\\\nconsole.log('fake')"
    account = ProfileAccount.new(id: 78, display_name: name, headline: "작가")
    verify_script = lambda do |script, timeout|
      assert_equal 300, timeout
      payload, body = script.split("\n", 2)
      assert_equal({
        "account_id" => 78, "display_name" => name, "job" => "작가", "ename" => "Name \"Q\"",
        "sites" => [ "https://example.test/?q=1" ], "probe" => true
      }, JSON.parse(payload.delete_prefix("const FILL = ").delete_suffix(";")))
      assert_equal SCRIPT_PATH.read, body
      { "ok" => true }
    end
    runner = Object.new
    runner.define_singleton_method(:run_script) { |script, timeout:| verify_script.call(script, timeout) }

    result = EgoProfile::NaverSubmissionFiller.new(runner: runner).call(account: account,
      ename: 'Name "Q"', sites: [ "https://example.test/?q=1" ], probe: true)
    assert_equal({ "ok" => true }, result)
  end

  test "converts runner errors into failure results" do
    runner = Object.new
    runner.define_singleton_method(:run_script) { |*, **| raise EgoProfile::Error, "timeout" }

    assert_equal({ "ok" => false, "reason" => "timeout" },
      EgoProfile::NaverSubmissionFiller.new(runner: runner).call(account: ProfileAccount.new))
  end

  test "clicks no application or submission button and advances only while selecting the person" do
    script = SCRIPT_PATH.read
    refute_match(/\.click\s*\([^\n]*(?:신청|제출|완료)/, script)
    assert_equal 1, script.scan(/\.click\s*\([^\n]*다음/).size
    assert_match(/if \(!await atStep\(page, null\)\)[^\n]*\n\s*await page\.click\([^\n]*다음/, script)
    assert_equal [ "사이트 추가", "추가하기", "취소" ], script[/const siteButtons = \{(.*?)\};/m, 1].scan(/"([^"]+)"/).flatten
  end
end
