require "test_helper"

class EgoProfile::InvitationExecutorTest < ActiveSupport::TestCase
  test "passes a JSON-escaped approval to the runner with a 120-second timeout" do
    name = "가상 \"인물\"\\\nconsole.log('fake')"
    account = ProfileAccount.new(login_id: "sample-member")
    action = LinkedinInvitationAction.new(profile_account: account, name: name, kind: "connection",
      action: "accept", headline: "개발자")
    verify_script = lambda do |script, timeout|
      assert_equal 120, timeout
      payload, body = script.split("\n", 2)
      assert_equal({ "name" => name, "kind" => "connection", "decision" => "accept",
        "headline" => "개발자", "login_id" => "sample-member" },
        JSON.parse(payload.delete_prefix("const ACTION = ").delete_suffix(";")))
      assert_equal File.read(Rails.root.join("lib/ego/linkedin_invitation_action.mjs")), body
      { "ok" => true }
    end
    runner = Object.new
    runner.define_singleton_method(:run_script) { |script, timeout:| verify_script.call(script, timeout) }

    assert_equal({ "ok" => true }, EgoProfile::InvitationExecutor.new(runner: runner).call(action))
  end
end
