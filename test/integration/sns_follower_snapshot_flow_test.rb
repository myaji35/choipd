require "test_helper"

# ISS-431 — 추종자 스냅샷: 실제 HTTP 요청으로 화면·저장 경로를 검증한다.
class SnsFollowerSnapshotFlowTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(
      name: "팔로워테스트",
      email: "follower-test-#{SecureRandom.hex(4)}@example.com",
      slug: "follower-test-#{SecureRandom.hex(4)}"
    )
    @member.update_columns(password_digest: nil)
    @account = @member.sns_accounts.create!(platform: "instagram", account_name: "@flow_test", is_active: true)
    @member.sns_accounts.create!(platform: "youtube", account_name: "@flow_tube", is_active: true)
    @base = "/#{@member.slug}/admin/sns_accounts"
  end

  test "스냅샷이 없으면 0이 아니라 미입력으로 표시된다" do
    get @base
    assert_response :success
    assert_match "미입력", response.body
  end

  test "폼 제출로 manual 스냅샷이 생성되고 최신값이 화면에 나온다" do
    assert_difference "SnsFollowerSnapshot.count", 1 do
      post "#{@base}/#{@account.id}/follower_snapshots",
           params: { sns_follower_snapshot: { follower_count: 1234 } }
    end
    assert_redirected_to @base
    snap = SnsFollowerSnapshot.order(:id).last
    assert_equal "manual", snap.source
    assert_equal @account.id, snap.sns_account_id
    assert_not_nil snap.captured_at

    follow_redirect!
    assert_match "1,234", response.body
  end

  test "두 번 입력하면 증감이 표시된다" do
    post "#{@base}/#{@account.id}/follower_snapshots", params: { sns_follower_snapshot: { follower_count: 100 } }
    post "#{@base}/#{@account.id}/follower_snapshots", params: { sns_follower_snapshot: { follower_count: 180 } }
    get @base
    assert_response :success
    assert_match "+80", response.body
  end

  test "음수는 거부되고 스냅샷이 생기지 않는다" do
    assert_no_difference "SnsFollowerSnapshot.count" do
      post "#{@base}/#{@account.id}/follower_snapshots",
           params: { sns_follower_snapshot: { follower_count: -10 } }
    end
    assert_redirected_to @base
  end

  test "타인 계정에는 스냅샷을 만들 수 없다" do
    other = Member.where.not(id: @member.id).first
    skip "다른 회원 없음" if other.nil?
    foreign = other.sns_accounts.create!(platform: "twitter", account_name: "@foreign", is_active: true)
    assert_no_difference "SnsFollowerSnapshot.count" do
      assert_raises(ActiveRecord::RecordNotFound) do
        post "#{@base}/#{foreign.id}/follower_snapshots",
             params: { sns_follower_snapshot: { follower_count: 999 } }
      end
    end
  end

  test "대시보드는 미입력 계정을 합계에서 빼고 그 수를 표기한다" do
    post "#{@base}/#{@account.id}/follower_snapshots", params: { sns_follower_snapshot: { follower_count: 500 } }
    get "/#{@member.slug}/admin/dashboard"
    assert_response :success
    assert_match "총 추종자", response.body
    assert_match "500", response.body
    assert_match "1개 계정 미입력", response.body
  end
end
