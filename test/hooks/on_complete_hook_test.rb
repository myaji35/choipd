require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class OnCompleteHookTest < ActiveSupport::TestCase
  test "preserves quoted text and backslashes in the result JSON" do
    criterion = 'a "따옴표" b'
    output = '{"k":"v"} 경로 C:\\tmp'
    registry = run_hook("DESIGN_FIX", {
      "criteria_check" => [ { "criterion" => criterion, "met" => true } ],
      "proof" => [ { "cmd" => "x", "output" => output } ]
    })

    result = registry.fetch("issues").find { |issue| issue.fetch("id") == "ISS-1" }.fetch("result")
    refute result.key?("raw")
    assert_equal criterion, result.dig("criteria_check", 0, "criterion")
    assert_equal output, result.dig("proof", 0, "output")
  end

  test "does not create derivative issues when the fix is already complete" do
    registry = run_hook("DESIGN_FIX", { "resolution" => "already_fixed" })

    assert_equal [ "ISS-1" ], registry.fetch("issues").map { |issue| issue.fetch("id") }
  end

  test "does not create derivative issues when skip_derivatives is empty and the fix is already complete" do
    registry = run_hook("DESIGN_FIX", { "skip_derivatives" => "", "resolution" => "already_fixed" })

    assert_equal [ "ISS-1" ], registry.fetch("issues").map { |issue| issue.fetch("id") }
  end

  test "creates test and domain analysis issues for a design fix" do
    registry = run_hook("DESIGN_FIX", { "files_modified" => [ "app/views/x.html.erb" ] })

    derivatives = registry.fetch("issues").select { |issue| issue["parent_id"] == "ISS-1" }
    types = derivatives.map { |issue| issue.fetch("type") }
    assert_includes types, "RUN_TESTS"
    assert_includes types, "DOMAIN_ANALYZE"
  end

  private

  def run_hook(issue_type, result)
    freeze_path = "/tmp/harness-freeze.env"
    freeze_existed = File.exist?(freeze_path)
    freeze_contents = File.binread(freeze_path) if freeze_existed

    Dir.mktmpdir do |tmp|
      registry_path = File.join(tmp, ".claude/issue-db/registry.json")
      hooks_path = File.join(tmp, ".claude/hooks")
      FileUtils.mkdir_p([ File.dirname(registry_path), hooks_path ])
      FileUtils.cp(Rails.root.join(".claude/hooks/on_complete.sh"), hooks_path)
      dispatch_path = File.join(hooks_path, "dispatch-ready.sh")
      File.write(dispatch_path, "#!/bin/bash\nexit 0\n")
      File.chmod(0o755, dispatch_path)
      File.write(registry_path, JSON.generate({
        stats: { total_issues: 1 },
        issues: [ {
          id: "ISS-1",
          type: issue_type,
          status: "IN_PROGRESS",
          priority: "P1",
          title: "t",
          payload: { files: [ "app/views/x.html.erb" ] }
        } ]
      }))

      output, status = Open3.capture2e("bash", ".claude/hooks/on_complete.sh", "ISS-1", issue_type, JSON.generate(result), chdir: tmp)
      assert status.success?, "on_complete.sh failed (#{status}):\n#{output}"

      JSON.parse(File.read(registry_path))
    end
  ensure
    assert_equal freeze_existed, File.exist?(freeze_path), "#{freeze_path} existence changed"
    assert File.binread(freeze_path) == freeze_contents, "#{freeze_path} contents changed" if freeze_existed
  end
end
