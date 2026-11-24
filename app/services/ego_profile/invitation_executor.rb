module EgoProfile
  class InvitationExecutor
    def initialize(runner: Runner.new)
      @runner = runner
    end

    def call(action)
      payload = JSON.generate(name: action.name, kind: action.kind, decision: action.action,
        headline: action.headline, login_id: action.profile_account.login_id)
      script = File.read(Rails.root.join("lib/ego/linkedin_invitation_action.mjs"))
      @runner.run_script("const ACTION = #{payload};\n#{script}", timeout: 120)
    rescue Error => e
      { "ok" => false, "reason" => e.message }
    end
  end
end
