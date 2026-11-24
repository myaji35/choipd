module EgoProfile
  class NaverSubmissionFiller
    def initialize(runner: Runner.new)
      @runner = runner
    end

    def call(account:, ename: nil, sites: [], probe: false, job: account.headline)
      payload = JSON.generate(account_id: account.id, display_name: account.display_name,
        job: job, ename: ename, sites: sites, probe: probe)
      script = File.read(Rails.root.join("lib/ego/naver_people_modify_fill.mjs"))
      @runner.run_script("const FILL = #{payload};\n#{script}", timeout: 300)
    rescue Error => e
      { "ok" => false, "reason" => e.message }
    end
  end
end
