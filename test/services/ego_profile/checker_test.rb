require "test_helper"

class EgoProfile::CheckerTest < ActiveSupport::TestCase
  class FakeRunner
    attr_accessor :response
    def initialize(response) = @response = response
    def call(_platform)
      raise response if response.is_a?(Exception)
      response
    end
  end

  setup do
    @runner = FakeRunner.new({ "logged_in" => true, "accounts" => [ { "external_id" => "fake-id", "display_name" => "가상 인물", "data" => { "value" => 1 } } ] })
    @checker = EgoProfile::Checker.new(runner: @runner, tenant_id: 7)
  end

  test "creates account and snapshots only when data changes" do
    result = @checker.call("linkedin")
    assert_equal [ 1, 1 ], [ result.accounts_count, result.changed_count ]
    account = ProfileAccount.find_by!(tenant_id: 7, external_id: "fake-id")
    assert_equal "logged_in", account.session_status
    assert_equal 1, account.profile_snapshots.count
    assert_equal 0, @checker.call("linkedin").changed_count
    @runner.response["accounts"][0]["data"] = { "value" => 2 }
    assert_equal 1, @checker.call("linkedin").changed_count
    assert_equal 2, account.profile_snapshots.count
  end

  test "logged out marks existing accounts" do
    @checker.call("linkedin")
    @runner.response = { "logged_in" => false }
    @checker.call("linkedin")
    account = ProfileAccount.find_by!(tenant_id: 7)
    assert_equal "logged_out", account.session_status
    assert_nil account.last_error
    assert_not_nil account.last_checked_at
  end

  test "error response and runner exception mark existing accounts" do
    @checker.call("linkedin")
    [ { "error" => "가상 오류" }, EgoProfile::Error.new("실행 오류") ].each do |error|
      @runner.response = error
      result = @checker.call("linkedin")
      account = ProfileAccount.find_by!(tenant_id: 7)
      assert_equal "error", account.session_status
      assert_equal result.error, account.last_error
      assert_not_nil account.last_checked_at
    end
  end
  test "limits response and runner errors to 500 characters" do
    @checker.call("linkedin")
    [ { "error" => "가" * 600 }, EgoProfile::Error.new("나" * 600) ].each do |error|
      @runner.response = error
      result = @checker.call("linkedin")
      assert_equal 500, result.error.length
      assert_equal result.error, ProfileAccount.find_by!(tenant_id: 7).last_error
    end
  end
end
