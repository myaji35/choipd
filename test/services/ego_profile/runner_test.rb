require "test_helper"

class EgoProfile::RunnerTest < ActiveSupport::TestCase
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
  private

  def with_capture(stdout, stderr)
    runner_class = EgoProfile::Runner.singleton_class
    open3_class = Open3.singleton_class
    runner_class.alias_method :original_binary_for_test, :binary
    open3_class.alias_method :original_capture3_for_test, :capture3
    runner_class.define_method(:binary) { "/fake/ego-browser" }
    open3_class.define_method(:capture3) { |*args, **kwargs| [ stdout, stderr, nil ] }
    yield
  ensure
    runner_class.alias_method :binary, :original_binary_for_test
    runner_class.remove_method :original_binary_for_test
    open3_class.alias_method :capture3, :original_capture3_for_test
    open3_class.remove_method :original_capture3_for_test
  end

end
