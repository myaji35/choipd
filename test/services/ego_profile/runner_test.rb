require "test_helper"

class EgoProfile::RunnerTest < ActiveSupport::TestCase
  test "prefixes the script with account-specific JSON input and budgets for default searches" do
    runner = EgoProfile::Runner.new
    captured = []
    runner.define_singleton_method(:run_script) { |script, timeout:| captured << [ script, timeout ] }
    queries = { "123" => [ "강승식", "따옴표 \"와\n줄바꿈" ], "456" => [ "강승식" ] }

    runner.call("naver_people", search_queries_by_account: queries, default_search_accounts: 2)
    runner.call("linkedin")

    script, timeout = captured.first
    prefix, body = script.split("\n", 2)
    assert_equal({ "search_queries_by_account" => queries }, JSON.parse(prefix.delete_prefix("const INPUT = ").delete_suffix(";")))
    assert_equal 240 + (2 + 1 + 3 * 2) * 18, timeout
    assert_equal File.read(Rails.root.join("lib/ego/naver_people_check.mjs")), body
    assert captured.second.first.start_with?("const INPUT = {};\n")
    assert_equal 240, captured.second.last
  end

  test "parses the last result from stderr" do
    output = "diagnostic\nEGO_RESULT {\"logged_in\":false}\nEGO_RESULT {\"logged_in\":true}\n"
    with_capture("", output) do
      assert_equal({ "logged_in" => true }, EgoProfile::Runner.new.call("linkedin"))
    end
  end

  test "prefers the last stdout result over stderr" do
    stdout = "EGO_RESULT {\"logged_in\":false}\nEGO_RESULT {\"logged_in\":true}\n"
    stderr = "EGO_RESULT {\"logged_in\":false}\n"
    with_capture(stdout, stderr) do
      assert_equal({ "logged_in" => true }, EgoProfile::Runner.new.call("linkedin"))
    end
  end

  test "limits stderr diagnostics and excludes result lines on parse errors" do
    stderr = "a" * 400 + "\nEGO_RESULT invalid secret payload\n" + "b" * 200
    with_capture("", stderr) do
      error = assert_raises(EgoProfile::Error) { EgoProfile::Runner.new.call("linkedin") }
      assert_not_includes error.message, "secret payload"
      assert error.message.end_with?(("a" * 400 + "\n" + "b" * 200).last(300))
    end
  end
  test "places the named Ego server before the nodejs subcommand" do
    calls = []
    with_capture("EGO_RESULT {}\n", "", calls: calls) do
      runner = EgoProfile::Runner.new
      runner.run_script("script", timeout: 120, server_name: "m6.brand")
      runner.run_script("script", timeout: 120)
    end
    assert_equal [
      [ "/fake/ego-browser", "--ego-server-name=m6.brand", "nodejs" ],
      [ "/fake/ego-browser", "nodejs" ]
    ], calls
  end

  private

  def with_capture(stdout, stderr, calls: [])
    runner_class = EgoProfile::Runner.singleton_class
    open3_class = Open3.singleton_class
    runner_class.alias_method :original_binary_for_test, :binary
    open3_class.alias_method :original_capture3_for_test, :capture3
    runner_class.define_method(:binary) { "/fake/ego-browser" }
    open3_class.define_method(:capture3) do |*args, **kwargs|
      calls << args
      [ stdout, stderr, nil ]
    end
    yield
  ensure
    runner_class.alias_method :binary, :original_binary_for_test
    runner_class.remove_method :original_binary_for_test
    open3_class.alias_method :capture3, :original_capture3_for_test
    open3_class.remove_method :original_capture3_for_test
  end
end
