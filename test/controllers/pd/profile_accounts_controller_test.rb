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
    assert_select "h1", count: 1
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

  test "naver displays applications, rejection reason, changes and delegation warning" do
    travel_to Time.zone.local(2026, 11, 24, 12)
    account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물", external_id: "fake-naver")
    account.profile_snapshots.create!(captured_at: 1.day.ago, data: {
      "applications" => { "ING" => [], "END" => [] }
    })
    account.profile_snapshots.create!(captured_at: Time.current, data: {
      "auth" => { "delegEndDate" => "2026-12-01" },
      "applications" => {
        "ING" => { "content" => [ { "applyId" => 1, "itemName" => "직업", "applyDate" => "2026-11-23", "statusName" => "접수" } ] },
        "END" => [ { "applyId" => 2, "itemName" => "소속", "applyDate" => "2026-11-20", "statusName" => "반려", "rejectReason" => "증빙 자료 필요" } ]
      }
    })

    get pd_profile_account_path(account)
    assert_response :success
    assert_select "h2", text: "신청 내역"
    assert_select "h3", text: "진행 중 1건"
    assert_select "h3", text: "완료 1건"
    assert_select "li", text: "직업 · 2026-11-23 · 접수"
    assert_select "p.text-red-600", text: "반려 사유: 증빙 자료 필요"
    assert_select "h3", text: "최근 신청 변화"
    assert_select "li", text: "새 신청 · 직업 · - → 접수"
    assert_select "p", text: "권한 위임이 7일 뒤(2026-12-01) 끝납니다. 본인참여 사이트에서 연장하세요."

    get pd_profile_accounts_path
    assert_response :success
    assert_select "td p", text: "위임 종료 임박 D-7"
  end

  test "naver show explains how applications will appear for old snapshots" do
    account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물", external_id: "fake-naver")
    account.profile_snapshots.create!(captured_at: Time.current, data: { "people" => {} })

    get pd_profile_account_path(account)
    assert_response :success
    assert_select "p", text: "다음 점검부터 신청 내역을 모읍니다."
  end

  test "linkedin show displays activity metrics and posts from snapshots" do
    dashboard = file_fixture("linkedin/dashboard.txt").read
    activity = file_fixture("linkedin/activity.txt").read
    links = JSON.parse(file_fixture("linkedin/activity_links.json").read)
    @account.profile_snapshots.create!(captured_at: Time.current, data: {
      "pages" => {
        "dashboard" => { "text" => dashboard },
        "activity" => { "text" => activity, "links" => links }
      }
    })

    get pd_profile_account_path(@account)

    assert_response :success
    assert_select "h2", text: "활동 지표"
    assert_select "h2", text: "날짜별 추이"
    assert_select "h2", text: "내 게시물·글"
    assert_select "h2", text: "주간 활동 권장"
    assert_select "a[href=?]", links.first, text: "Data Pipelines That Explain Themselves"
  end

  test "linkedin show displays profile, revision history and latest active naver comparison" do
    pages = %w[profile experience education skills certifications].index_with do |name|
      { "text" => file_fixture("linkedin/#{name}.txt").read }
    end
    @account.profile_snapshots.create!(captured_at: 3.days.ago, data: { "pages" => pages.deep_dup })
    @account.profile_snapshots.create!(captured_at: 2.days.ago, data: { "miniProfile" => {} })
    pages["profile"]["text"] = pages["profile"]["text"].sub("데이터 분석 컨설턴트", "분석 교육자")
    @account.profile_snapshots.create!(captured_at: 1.day.ago, data: { "pages" => pages })
    @account.profile_snapshots.create!(captured_at: 1.hour.ago, data: {
      "pages" => { "profile" => { "error" => "timeout", "text" => "읽을 수 없는 프로필" },
                   "experience" => {}, "activity" => { "text" => "" } }
    })

    get pd_profile_account_path(@account)
    assert_response :success
    assert_select "h2", text: /프로필 완성도 \d+%/
    assert_select "h3", text: /이전 사본/, count: 1
    assert_select "h2", text: "프로필 변경 내역"
    assert_select "li", text: /헤드라인.*데이터 분석 컨설턴트.*분석 교육자/m
    assert_select "h2", text: "네이버 인물정보와 다른 점"
    assert_includes response.body, "비교할 네이버 인물정보 사본이 없습니다"

    ProfileAccount.create!(platform: "naver_people", display_name: "사본 없는 계정", tenant_id: @account.tenant_id)
    naver = ProfileAccount.create!(platform: "naver_people", display_name: "홍길동", tenant_id: @account.tenant_id)
    naver.profile_snapshots.create!(captured_at: Time.current, data: {
      "people" => { "peopleOffice" => [ { "name" => "한빛랩", "position" => "대표", "current" => "Y" } ] }
    })

    get pd_profile_account_path(@account)
    assert_select "p", text: "현재 직함 · 직함 다름"
  end

  test "linkedin show reports that a profile with no comparison sections cannot be compared" do
    @account.profile_snapshots.create!(captured_at: Time.current, data: {
      "pages" => { "profile" => { "text" => "홍길동\n개발자" } }
    })
    naver = ProfileAccount.create!(platform: "naver_people", display_name: "홍길동", tenant_id: @account.tenant_id)
    naver.profile_snapshots.create!(captured_at: Time.current, data: { "people" => {} })

    get pd_profile_account_path(@account)

    assert_response :success
    assert_select "p", text: "LinkedIn 프로필을 아직 읽지 못해 비교하지 못했습니다"
    assert_select "p", text: "다른 점이 없습니다.", count: 0
  end

  test "linkedin show displays network counts and approval forms" do
    create_network_snapshot

    get pd_profile_account_path(@account)

    assert_response :success
    assert_select "h2", text: "LinkedIn 인맥"
    assert_select "dt", text: "1촌"
    assert_select "dd", text: "15"
    assert_select "td", text: "12"
    assert_select "form[action=?][data-turbo-confirm]", invitation_action_pd_profile_account_path(@account), count: 2 do
      assert_select "button", text: "수락 승인"
      assert_select "button", text: "건너뛰기 승인"
    end
  end

  test "invitation action records an approval before executing and displays completion" do
    create_network_snapshot
    execute = lambda do |approval|
      assert_equal "approved", approval.reload.status
      assert approval.approved_at
      assert_equal "accept", approval.action
      assert_equal "가상 신청자", approval.name
      { "ok" => true }
    end

    with_invitation_executor(execute) do
      post invitation_action_pd_profile_account_path(@account), params: { invitation_key: "connection:가상 신청자:개발자", decision: "accept" }
    end

    assert_redirected_to pd_profile_account_path(@account)
    assert_equal "LinkedIn 신청을 수락했습니다.", flash[:notice]
    approval = @account.linkedin_invitation_actions.sole
    assert_equal "done", approval.status
    assert approval.executed_at
    follow_redirect!
    assert_select "p", text: /수락함 \(/
    assert_select "button", text: "수락 승인", count: 0
  end

  test "invitation action records and displays a browser failure" do
    create_network_snapshot
    reason = "같은 이름 버튼이 여러 개"
    with_invitation_executor(->(_) { { "ok" => false, "reason" => reason } }) do
      post invitation_action_pd_profile_account_path(@account), params: { invitation_key: "connection:가상 신청자:개발자", decision: "ignore" }
    end

    assert_redirected_to pd_profile_account_path(@account)
    assert_equal reason, flash[:alert]
    approval = @account.linkedin_invitation_actions.sole
    assert_equal "failed", approval.status
    assert_equal reason, approval.result_message
    assert approval.executed_at
    follow_redirect!
    assert_select "p", text: "실패: #{reason}"
    assert_select "button", text: "건너뛰기 승인", count: 0
  end

  test "invitation action rejects a key absent from the latest network snapshot" do
    create_network_snapshot
    with_invitation_executor(->(_) { flunk "unexpected execution" }) do
      assert_no_difference "LinkedinInvitationAction.count" do
        post invitation_action_pd_profile_account_path(@account), params: { invitation_key: "connection:없는 신청:", decision: "accept" }
      end
    end

    assert_redirected_to pd_profile_account_path(@account)
    assert_equal "목록에 없는 신청입니다", flash[:alert]
  end

  test "invitation action does not execute a done key even for a different decision" do
    create_network_snapshot
    @account.linkedin_invitation_actions.create!(
      invitation_key: "connection:가상 신청자:개발자", name: "가상 신청자", action: "accept", status: "done", executed_at: Time.current
    )

    with_invitation_executor(->(_) { flunk "unexpected execution" }) do
      assert_no_difference "LinkedinInvitationAction.count" do
        post invitation_action_pd_profile_account_path(@account), params: { invitation_key: "connection:가상 신청자:개발자", decision: "ignore" }
      end
    end

    assert_redirected_to pd_profile_account_path(@account)
    assert_equal "이미 처리한 신청입니다.", flash[:alert]
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

  private

  def create_network_snapshot
    @account.profile_snapshots.create!(captured_at: Time.current, data: {
      "pages" => {
        "network" => { "text" => "12\n초대 보냄\n15\n1촌\n9\n팔로우중" },
        "invitations" => { "text" => "가상 신청자 님이 1촌이 되고 싶어 함\n개발자\n건너뛰기\n수락" }
      },
      "nav_badges" => { "messages" => 0, "notifications" => 3 }
    })
  end

  def with_invitation_executor(execute)
    executor = Object.new
    executor.define_singleton_method(:call) { |approval| execute.call(approval) }
    original = EgoProfile::InvitationExecutor.method(:new)
    EgoProfile::InvitationExecutor.define_singleton_method(:new) { executor }
    yield
  ensure
    EgoProfile::InvitationExecutor.define_singleton_method(:new, original)
  end
end
