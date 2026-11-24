module BrandChannels
  class SessionPatrol
    PLATFORMS = %w[naver_blog naver_people].freeze

    def initialize(runner: EgoProfile::Runner.new)
      @runner = runner
    end

    def call(brand_id: nil)
      channels = BrandChannel.where(connection_method: "ego_session", platform: PLATFORMS)
      channels = channels.where(brand_id: brand_id) if brand_id.present?
      channels.find_each.map { |channel| check(channel) }
    end

    private

    def check(channel)
      status, error = session_state(run_check(channel))
      channel.update!(session_status: status, last_error: error, last_checked_at: Time.current)
      [ "#{channel.id} (#{channel.platform})", status, error ].compact.join(" · ")
    end

    def run_check(channel)
      payload = JSON.generate(platform: channel.platform, account_handle: channel.account_handle)
      script = File.read(Rails.root.join("lib/ego/brand_channel_check.mjs"))
      @runner.run_script("const CHECK = #{payload};\n#{script}", timeout: 120, server_name: channel.ego_server_name)
    rescue EgoProfile::Error => e
      { "error" => e.message }
    end

    def session_state(result)
      return [ "error", result["error"].to_s.first(500) ] if result["error"]
      return [ "logged_out", nil ] unless result["logged_in"] == true
      return [ "connected", nil ] if result["matches"] == true

      masked_id = "#{result['login_id'].to_s.first(2)}***"
      [ "logged_out", "다른 네이버 계정(#{masked_id})이 로그인되어 있습니다" ]
    end
  end
end
