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
