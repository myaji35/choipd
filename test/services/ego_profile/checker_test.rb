require "test_helper"

class EgoProfile::CheckerTest < ActiveSupport::TestCase
  class FakeRunner
    attr_accessor :response
    def initialize(response) = @response = response
    attr_reader :input

    def call(_platform, input = {})
      @input = input
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

  test "passes configured queries by active naver account for the tenant" do
    [
      [ 7, "naver_people", true, [ "강승식", "강승식 기업인" ] ],
      [ 7, "naver_people", true, [ "강승식", "강승식 가가호호" ] ],
      [ 7, "naver_people", true, [] ],
      [ 7, "naver_people", false, [ "비활성" ] ],
      [ 8, "naver_people", true, [ "다른 테넌트" ] ],
      [ 7, "linkedin", true, [ "다른 플랫폼" ] ]
    ].each_with_index do |(tenant, platform, active, queries), index|
      ProfileAccount.create!(tenant_id: tenant, platform: platform, external_id: index.to_s, is_active: active,
                             display_name: "가상 인물", search_query_list: queries)
    end

    @checker.call("naver_people")
    assert_equal({ search_queries_by_account: {
      "0" => [ "강승식", "강승식 기업인" ],
      "1" => [ "강승식", "강승식 가가호호" ]
    }, default_search_accounts: 2 }, @runner.input)
    @checker.call("linkedin")
    assert_empty @runner.input
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
