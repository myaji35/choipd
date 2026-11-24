require "test_helper"

class BrandChannels::SessionPatrolTest < ActiveSupport::TestCase
  test "checks only supported Ego channels in the selected brand and records each session outcome" do
    brand = Brand.create!(name: "점검 브랜드")
    channels = %w[error logged_out mismatch connected].map do |handle|
      brand.brand_channels.create!(platform: handle == "connected" ? "naver_people" : "naver_blog",
        account_handle: handle, ego_server_name: "m6.#{handle}", last_error: "이전 오류")
    end
    skipped = [
      brand.brand_channels.create!(platform: "linkedin_profile"),
      brand.brand_channels.create!(platform: "naver_blog", connection_method: "manual"),
      Brand.create!(name: "다른 브랜드").brand_channels.create!(platform: "naver_blog")
    ]
    responses = {
      "error" => { "error" => "오" * 510 },
      "logged_out" => { "logged_in" => false },
      "mismatch" => { "logged_in" => true, "matches" => false, "login_id" => "other-id" },
      "connected" => { "logged_in" => true, "matches" => true }
    }
    calls = []
    runner = Object.new
    runner.define_singleton_method(:run_script) do |script, timeout:, server_name:|
      input = JSON.parse(script.lines.first.delete_prefix("const CHECK = ").strip.delete_suffix(";"))
      handle = input.fetch("account_handle")
      calls << [ input.fetch("platform"), handle, timeout, server_name ]
      responses.fetch(handle)
    end

    freeze_time do
      summaries = BrandChannels::SessionPatrol.new(runner: runner).call(brand_id: brand.id)
      assert_equal 4, summaries.size
      assert_equal channels.map { |channel| [ channel.platform, channel.account_handle, 120, channel.ego_server_name ] }, calls
      channels.each { |channel| assert_equal Time.current, channel.reload.last_checked_at }
      assert_equal %w[error logged_out logged_out connected], channels.map(&:session_status)
      assert_equal "오" * 500, channels[0].last_error
      assert_nil channels[1].last_error
      assert_equal "다른 네이버 계정(ot***)이 로그인되어 있습니다", channels[2].last_error
      assert_nil channels[3].last_error
      skipped.each { |channel| assert_nil channel.reload.last_checked_at }
    end
  end

  test "records runner exceptions as session errors" do
    channel = Brand.create!(name: "점검 브랜드").brand_channels.create!(platform: "naver_blog")
    runner = Object.new
    runner.define_singleton_method(:run_script) { |*, **| raise EgoProfile::Error, "실행 오류" }

    assert_equal [ "#{channel.id} (naver_blog) · error · 실행 오류" ], BrandChannels::SessionPatrol.new(runner: runner).call
    assert_equal "error", channel.reload.session_status
  end
end
