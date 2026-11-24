module EgoProfile
  class LinkedinPublisher
    def initialize(runner: Runner.new)
      @runner = runner
    end

    def call(kind:, account:, text: nil, title: nil, body: nil, newsletter_name: nil, probe: false)
      payload = JSON.generate(kind: kind, login_id: account.login_id, text: text, title: title,
        body: body, newsletter_name: newsletter_name, probe: probe)
      script = File.read(Rails.root.join("lib/ego/linkedin_publish.mjs"))
      @runner.run_script("const PUBLISH = #{payload};\n#{script}", timeout: 240)
    rescue Error => e
      reason = e.message
      reason += " · LinkedIn 글 임시저장에 남아 있을 수 있음" if kind == "article" && !probe
      { "ok" => false, "reason" => reason }
    end
  end
end
