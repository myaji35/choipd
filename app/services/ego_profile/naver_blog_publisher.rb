module EgoProfile
  class NaverBlogPublisher
    def initialize(runner: Runner.new)
      @runner = runner
    end

    def call(channel:, title: nil, body: nil, probe: false)
      payload = JSON.generate(account_handle: channel.account_handle, title: title, body: body, probe: probe)
      script = File.read(Rails.root.join("lib/ego/naver_blog_publish.mjs"))
      @runner.run_script("const PUBLISH = #{payload};\n#{script}", timeout: 240, server_name: channel.ego_server_name)
    rescue Error => e
      { "ok" => false, "reason" => e.message }
    end
  end
end
