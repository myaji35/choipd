require "test_helper"

class EgoProfile::LinkedinPublisherTest < ActiveSupport::TestCase
  test "passes a JSON-escaped payload to the runner with a 240-second timeout" do
    body = "가상 \"내용\"\\\nconsole.log('fake')"
    account = ProfileAccount.new(login_id: "test-member")
    verify_script = lambda do |script, timeout|
      assert_equal 240, timeout
      payload, source = script.split("\n", 2)
      assert_equal({ "kind" => "article", "login_id" => "test-member", "text" => nil,
        "title" => "제목", "body" => body, "newsletter_name" => "Dev Notes", "probe" => true },
        JSON.parse(payload.delete_prefix("const PUBLISH = ").delete_suffix(";")))
      assert_equal File.read(Rails.root.join("lib/ego/linkedin_publish.mjs")), source
      { "ok" => true }
    end
    runner = Object.new
    runner.define_singleton_method(:run_script) { |script, timeout:| verify_script.call(script, timeout) }

    result = EgoProfile::LinkedinPublisher.new(runner: runner).call(
      kind: "article", account: account, title: "제목", body: body, newsletter_name: "Dev Notes", probe: true
    )
    assert_equal({ "ok" => true }, result)
  end

  test "returns browser errors as failures" do
    runner = Object.new
    runner.define_singleton_method(:run_script) { |*, **| raise EgoProfile::Error, "브라우저 오류" }
    result = EgoProfile::LinkedinPublisher.new(runner: runner).call(kind: "post", account: ProfileAccount.new)
    assert_equal({ "ok" => false, "reason" => "브라우저 오류" }, result)
  end
end
