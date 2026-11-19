require "test_helper"

class Pd::ProfileAccountsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in AdminUser.create!(email: "profile-test@example.test", password: "password123", role: "pd")
    @account = ProfileAccount.create!(platform: "linkedin", display_name: "가상 인물", external_id: "fake-id")
  end

  test "index lists account and detail and forms render" do
    get pd_profile_accounts_path
    assert_response :success
    assert_includes response.body, "가상 인물"
    get pd_profile_account_path(@account)
    assert_response :success
    get new_pd_profile_account_path
    assert_response :success
    get edit_pd_profile_account_path(@account)
    assert_response :success
  end

  test "naver show displays completeness and snapshot changes" do
    account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물", external_id: "fake-naver")
    account.profile_snapshots.create!(captured_at: 2.days.ago, data: { "people" => { "name" => "이전 이름" } })
    account.profile_snapshots.create!(captured_at: 1.day.ago, data: { "people" => { "name" => "새 이름" } })
    get pd_profile_account_path(account)
    assert_response :success
    assert_includes response.body, "완성도"
    assert_includes response.body, "변경 내역"
    assert_includes response.body, "이전 이름"
    assert_includes response.body, "새 이름"
    get pd_profile_accounts_path
    assert_includes response.body, "완성도 0%"
  end

  test "check reports missing browser" do
    original = EgoProfile::Runner.method(:available?)
    EgoProfile::Runner.define_singleton_method(:available?) { false }
    post check_pd_profile_accounts_path
    assert_redirected_to pd_profile_accounts_path
    assert_equal "ego 브라우저가 설치된 Mac에서만 점검할 수 있습니다.", flash[:alert]
  ensure
    EgoProfile::Runner.define_singleton_method(:available?, original)
  end

  test "create update and destroy" do
    assert_difference "ProfileAccount.count", 1 do
      post pd_profile_accounts_path, params: { profile_account: { platform: "naver_people", display_name: "새 가상 인물" } }
    end
    created = ProfileAccount.find_by!(display_name: "새 가상 인물")
    assert_redirected_to pd_profile_account_path(created)
    patch pd_profile_account_path(created), params: { profile_account: { display_name: "수정된 가상 인물" } }
    assert_redirected_to pd_profile_account_path(created)
    assert_equal "수정된 가상 인물", created.reload.display_name
    assert_difference "ProfileAccount.count", -1 do
      delete pd_profile_account_path(created)
    end
    assert_redirected_to pd_profile_accounts_path
  end
end
