require "test_helper"

class Pd::NaverPeopleTargetsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in AdminUser.create!(email: "naver-target@example.test", password: "password123", role: "pd")
    @account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물", tenant_id: 1)
    @path = pd_profile_account_naver_target_path(@account)
    @edit_path = edit_pd_profile_account_naver_target_path(@account)
    @approve_path = approve_pd_profile_account_naver_target_path(@account)
    add_naver_snapshot("기업인", 1.day.ago)
  end

  test "shows the draft sections and links from the account detail" do
    get @path
    assert_response :success
    assert_select "h2", text: "목표 프로필"
    assert_select "h2", text: "수정 신청 초안"
    assert_select "h2", text: "사이트 정보 대조"
    assert_select "p", text: "LinkedIn 사본이 없습니다."
    assert_select "a[href=?]", "#{@edit_path}?source=impd"

    get pd_profile_account_path(@account)
    assert_select "a[href=?]", @path, text: "목표 프로필·수정 신청 초안"
    assert_select "p", text: "승인 상태 초안"
  end

  test "defaults to the Naver snapshot and only prefills explicit imports" do
    assert_no_difference "NaverPeopleTarget.count" do
      get @edit_path
      assert_select "textarea[name='naver_people_target[jobs]']", text: "기업인"
    end

    target = @account.create_naver_people_target!(tenant_id: 1, values: { "jobs" => "작가" })
    get @edit_path, params: { source: "naver" }
    assert_select "[role=status]", text: /네이버에서 불러왔습니다. 확인 후 저장하세요./
    assert_select "textarea[name='naver_people_target[jobs]']", text: "기업인"
    assert_equal [ "작가" ], target.reload.values["jobs"]

    get @edit_path
    assert_select "textarea[name='naver_people_target[jobs]']", text: "작가"
  end

  test "prefills LinkedIn and imPD without saving a target" do
    member = Member.create!(name: @account.display_name, email: "naver-member@example.test", slug: "naver-member",
      tenant_id: 1, profession: "author")
    @account.update!(member: member)
    linkedin = ProfileAccount.create!(platform: "linkedin", display_name: member.name, member: member, tenant_id: 1)
    linkedin.profile_snapshots.create!(captured_at: Time.current, data: {
      "pages" => { "experience" => { "text" => file_fixture("linkedin/experience.txt").read } }
    })

    assert_no_difference "NaverPeopleTarget.count" do
      get @edit_path, params: { source: "linkedin" }
      assert_select "[role=status]", text: /LinkedIn에서 불러왔습니다/
      assert_select "textarea[name='naver_people_target[careers]']", text: /2026.07~현재 \| 한빛랩 CTO/

      get @edit_path, params: { source: "impd" }
      assert_select "[role=status]", text: /imPD에서 불러왔습니다/
      assert_select "textarea[name='naver_people_target[jobs]']", text: "작가"
    end
  end

  test "saves goals with the account tenant and preserves errors on invalid addresses" do
    patch @path, params: { naver_people_target: { jobs: "작가", status: "approved", tenant_id: 3 } }
    assert_response :see_other
    assert_redirected_to @path
    assert_equal "목표 프로필을 저장했습니다.", flash[:notice]
    target = @account.naver_people_target
    assert_equal [ 1, "draft", { "jobs" => [ "작가" ] } ], [ target.tenant_id, target.status, target.values ]

    patch @path, params: { naver_people_target: { sites: "ftp://invalid.test" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert] li", text: /사이트 주소/
    assert_select "textarea[name='naver_people_target[sites]']", text: "ftp://invalid.test"
    assert_equal({ "jobs" => [ "작가" ] }, target.reload.values)
  end

  test "refuses empty approval and detects a stale digest before reapproving and cancelling" do
    assert_no_difference "NaverPeopleTarget.count" do
      patch @approve_path
      assert_response :see_other
      assert_equal "바꿀 항목이 없습니다.", flash[:alert]
    end

    patch @path, params: { naver_people_target: { jobs: "작가" } }
    patch @approve_path
    assert_response :see_other
    assert_match(/수정 신청 초안을 승인했습니다/, flash[:notice])
    target = @account.naver_people_target
    digest = target.approved_draft_digest
    assert target.approved_current?(digest)
    assert target.approved_at

    follow_redirect!
    assert_select "strong", text: "승인됨"
    assert_select "table[aria-label='수정 신청 초안'] tbody tr", count: 2
    assert_select "input[type=checkbox]", count: 1

    add_naver_snapshot("프리랜서", Time.current)
    get @path
    assert_select "strong", text: "다시 승인 필요"
    assert_select "[role=alert]", text: "승인 이후 내용이 바뀌었습니다. 다시 승인하세요."
    get pd_profile_account_path(@account)
    assert_select "p", text: "승인 상태 다시 승인 필요"

    patch @approve_path
    assert_response :see_other
    refute_equal digest, target.reload.approved_draft_digest

    patch unapprove_pd_profile_account_naver_target_path(@account)
    assert_response :see_other
    assert_equal [ "draft", nil, nil ], target.reload.attributes.values_at("status", "approved_at", "approved_draft_digest")
  end

  test "shows an approved draft as fully reflected when the latest Naver snapshot matches" do
    patch @path, params: { naver_people_target: { jobs: "작가" } }
    patch @approve_path
    assert_equal "approved", @account.naver_people_target.status

    add_naver_snapshot("작가", Time.current)
    get @path
    assert_response :success
    assert_select "strong", text: "네이버에 모두 반영됨"
    assert_select "[role=alert]", text: /다시 승인하세요/, count: 0
    assert_select "form[action=?]", @approve_path, count: 0

    get pd_profile_account_path(@account)
    assert_select "p", text: "승인 상태 네이버에 모두 반영됨"
  end

  test "rejects LinkedIn accounts" do
    linkedin = ProfileAccount.create!(platform: "linkedin", display_name: "LinkedIn 계정")
    get pd_profile_account_naver_target_path(linkedin)
    assert_response :see_other
    assert_redirected_to pd_profile_account_path(linkedin)
    assert flash[:alert].present?
  end

  private

  def add_naver_snapshot(job, captured_at)
    @account.profile_snapshots.create!(captured_at: captured_at, data: { "people" => { "peopleJob" => [ { "nameTx" => job } ] } })
  end
end
