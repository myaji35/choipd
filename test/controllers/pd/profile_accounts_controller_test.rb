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
    assert_select "a[href=?]", weekly_report_pd_profile_accounts_path, text: "주간 리포트"
    get pd_profile_account_path(@account)
    assert_response :success
    get new_pd_profile_account_path
    assert_response :success
    assert_select "h1", text: "인물정보 계정 추가"
    assert_select "a[href=?]", pd_profile_accounts_path, text: "← 인물정보 계정"
    assert_select "a[href=?]", pd_profile_accounts_path, text: "취소"
    assert_select "input[type=submit][value='추가']"
    get edit_pd_profile_account_path(@account)
    assert_response :success
  end

  test "계정 등록 화면에서 주소의 플랫폼과 회원을 고정하고 입력 칸 네 개를 보여 준다" do
    member = Member.create!(name: "계정 등록 회원", email: "profile-new-member@example.test", slug: "profile-new-member")

    get new_pd_profile_account_path(member_id: member.id, platform: "linkedin")

    assert_response :ok
    assert_select "h1", text: "LinkedIn 계정 등록"
    assert_select "a[href=?]", pd_member_path(member, anchor: "accounts"), text: "← #{member.name} 대행 등록"
    assert_select "a[href=?]", pd_member_path(member, anchor: "accounts"), text: "취소"
    assert_select "#profile_account_display_name[value=?]", member.name
    assert_select "input[type=submit][value='계정 등록']"
    %w[display_name login_id external_id].each do |field|
      assert_select "input#profile_account_#{field}[aria-describedby=profile_account_#{field}_help] + p#profile_account_#{field}_help"
    end
    assert_select "input[type=hidden][name='profile_account[member_id]'][value=?]", member.id.to_s
    assert_select "input[type=hidden][name='profile_account[platform]'][value=linkedin]"
    assert_select "form select", count: 0
    assert_select "p", text: "회원: #{member.name} (/#{member.slug})"
    assert_select "p", text: "종류: LinkedIn"
    assert_select "form > div > input[type=text], form > div > textarea" do |fields|
      assert_equal %w[display_name login_id profile_url notes].map { |field| "profile_account_#{field}" }, fields.map { |field| field["id"] }
    end
    assert_select "details[open]", count: 0
    assert_select "details" do
      assert_select "summary", text: "더 적기 (외부 ID·직함 — 비워 둬도 등록됩니다)"
      assert_select "input#profile_account_external_id"
      assert_select "input#profile_account_headline"
      assert_select "input[type=checkbox]#profile_account_is_active"
    end
    assert_select "button[name=next][value='1']", text: "등록하고 다음"
    assert_select 'nav a[href=?][class~="bg-primary/10"]', pd_members_path, text: "회원 대행 등록"
    assert_select 'nav a[href=?][class~="bg-primary/10"]', pd_profile_accounts_path, count: 0
  end

  test "회원 계정을 등록하면 대행 등록 화면으로 돌아간다" do
    member = Member.create!(name: "계정 등록 회원", email: "profile-create@example.test", slug: "profile-create")
    post pd_profile_accounts_path, params: {
      profile_account: { member_id: member.id, platform: "linkedin", display_name: member.name }
    }

    assert_redirected_to pd_member_path(member, anchor: "accounts")
    assert_equal "LinkedIn 계정을 등록했습니다. 회원 대시보드 '내 프로필 관리 현황'에 바로 보입니다.", flash[:notice]
    follow_redirect!
    assert_select "#accounts a[href=?]", pd_profile_account_path(member.profile_accounts.sole), text: "계정 상세"
  end

  test "등록하고 다음으로 LinkedIn 폼, 이어서 첫 미등록 채널 폼으로 이동한다" do
    member = Member.create!(name: "이어 등록 회원", email: "profile-next@example.test", slug: "profile-next")

    post pd_profile_accounts_path, params: {
      next: "1", profile_account: { member_id: member.id, platform: "naver_people", display_name: member.name }
    }
    assert_redirected_to new_pd_profile_account_path(member_id: member.id, platform: "linkedin")
    assert_equal "네이버 인물정보 계정을 등록했습니다. 이어서 LinkedIn 계정을 등록하세요.", flash[:notice]
    follow_redirect!
    assert_select "h1", text: "LinkedIn 계정 등록"

    post pd_profile_accounts_path, params: {
      next: "1", profile_account: { member_id: member.id, platform: "linkedin", display_name: member.name }
    }
    assert_redirected_to new_pd_member_channel_path(member, platform: "naver_blog")
    assert_equal "LinkedIn 계정을 등록했습니다. 이어서 네이버 블로그 채널을 등록하세요.", flash[:notice]
    follow_redirect!
    assert_response :success
  end

  test "남은 등록이 없으면 등록하고 다음 버튼을 숨기고 대행 등록 화면으로 돌아간다" do
    member = Member.create!(name: "마지막 등록 회원", email: "profile-last@example.test", slug: "profile-last")
    member.profile_accounts.create!(platform: "naver_people", display_name: member.name)
    brand = member.ensure_personal_brand!
    MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.each_key do |platform|
      brand.brand_channels.create!(platform: platform)
    end

    get new_pd_profile_account_path(member_id: member.id, platform: "linkedin")
    assert_response :success
    assert_select "button[name=next]", count: 0

    post pd_profile_accounts_path, params: {
      next: "1", profile_account: { member_id: member.id, platform: "linkedin", display_name: member.name }
    }
    assert_redirected_to pd_member_path(member, anchor: "accounts")
    assert_equal "LinkedIn 계정을 등록했습니다. 회원 대시보드 '내 프로필 관리 현황'에 바로 보입니다.", flash[:notice]
  end

  test "회원과 플랫폼을 지정하지 않고 연 폼은 등록 실패 후에도 선택 칸을 유지한다" do
    member = Member.create!(name: "선택 회원", email: "profile-select@example.test", slug: "profile-select", status: "approved")

    get new_pd_profile_account_path
    assert_response :success
    assert_select "select#profile_account_member_id"
    assert_select "select#profile_account_platform"
    assert_select "details, button[name=next]", count: 0

    post pd_profile_accounts_path, params: {
      lock_member: css_select("input[name=lock_member]").first["value"],
      lock_platform: css_select("input[name=lock_platform]").first["value"],
      profile_account: { member_id: member.id, platform: "linkedin", display_name: "" }
    }

    assert_response :unprocessable_entity
    assert_select "select#profile_account_member_id option[selected][value=?]", member.id.to_s
    assert_select "select#profile_account_platform option[selected][value=linkedin]"
    assert_select "a[href=?]", pd_profile_accounts_path, text: "취소"
    assert_select 'nav a[href=?][class~="bg-primary/10"]', pd_members_path, text: "회원 대행 등록"
    assert_select 'nav a[href=?][class~="bg-primary/10"]', pd_profile_accounts_path, count: 0
  end

  test "고정된 회원 계정 등록은 실패 후에도 고정을 유지하고 추가 입력 영역을 펼친다" do
    member = Member.create!(name: "재입력 회원", email: "profile-retry@example.test", slug: "profile-retry")

    get new_pd_profile_account_path(member_id: member.id, platform: "linkedin")
    assert_response :success

    post pd_profile_accounts_path, params: {
      lock_member: css_select("input[name=lock_member]").first["value"],
      lock_platform: css_select("input[name=lock_platform]").first["value"],
      profile_account: { member_id: member.id, platform: "linkedin", display_name: "", headline: "편집자" }
    }

    assert_response :unprocessable_entity
    assert_select "input[type=hidden][name=lock_member][value='1']"
    assert_select "input[type=hidden][name=lock_platform][value='1']"
    assert_select "input[type=hidden][name='profile_account[member_id]'][value=?]", member.id.to_s
    assert_select "input[type=hidden][name='profile_account[platform]'][value=linkedin]"
    assert_select "form select", count: 0
    assert_select "a[href=?]", pd_member_path(member, anchor: "accounts"), text: "취소"
    assert_select 'nav a[href=?][class~="bg-primary/10"]', pd_members_path, text: "회원 대행 등록"
    assert_select 'nav a[href=?][class~="bg-primary/10"]', pd_profile_accounts_path, count: 0
    assert_select "details[open] input#profile_account_headline[value='편집자']"
  end

  test "회원 없이 계정을 추가하면 계정 상세로 이동한다" do
    post pd_profile_accounts_path, params: {
      profile_account: { platform: "naver_people", display_name: "직접 추가한 계정" }
    }

    account = ProfileAccount.find_by!(display_name: "직접 추가한 계정")
    assert_nil account.member_id
    assert_redirected_to pd_profile_account_path(account)
  end

  test "다른 테넌트 회원을 지정하면 생성과 수정을 거부하고 이름을 표시하지 않는다" do
    foreign_member = Member.create!(name: "외부 테넌트 회원", slug: "foreign-profile-member",
      email: "foreign-profile@example.test", tenant_id: 2, status: "approved")

    assert_no_difference "ProfileAccount.count" do
      post pd_profile_accounts_path, params: {
        profile_account: { member_id: foreign_member.id, platform: "linkedin", display_name: "새 계정" }
      }
    end
    assert_response 422
    assert_includes response.body, "회원을 찾을 수 없어요."
    assert_not_includes response.body, foreign_member.name

    assert_no_changes -> { @account.reload.attributes } do
      patch pd_profile_account_path(@account), params: {
        profile_account: { member_id: foreign_member.id, display_name: "수정한 계정" }
      }
    end
    assert_response 422
    assert_includes response.body, "회원을 찾을 수 없어요."
    assert_not_includes response.body, foreign_member.name

    @account.update!(member: foreign_member)
    get edit_pd_profile_account_path(@account)
    assert_response :ok
    assert_not_includes response.body, foreign_member.name
  end

  test "다른 테넌트 계정은 조회할 수 없다" do
    foreign_account = ProfileAccount.create!(platform: "linkedin", display_name: "외부 계정", tenant_id: 2)

    get pd_profile_account_path(foreign_account)

    assert_response :not_found
  end

  test "이미 연결된 계정의 연결 요청은 거부하고 대행 등록 화면으로 돌아간다" do
    original_member = Member.create!(name: "기존 연결 회원", email: "profile-original@example.test", slug: "profile-original")
    target_member = Member.create!(name: "연결 요청 회원", email: "profile-target@example.test", slug: "profile-target")
    @account.update!(member: original_member)

    assert_no_changes -> { @account.reload.attributes } do
      patch pd_profile_account_path(@account), params: {
        profile_account: { member_id: target_member.id }, link: "1"
      }
    end

    assert_response :see_other
    assert_redirected_to pd_member_path(target_member, anchor: "accounts")
    assert_equal "이미 다른 회원에게 연결된 계정이에요.", flash[:alert]
  end

  test "찾은 계정으로 바꾸면 손 등록 계정을 지우고 메모와 로그인 아이디를 옮긴다" do
    member = Member.create!(name: "교체 회원", email: "replace@example.test", slug: "replace")
    manual = member.profile_accounts.create!(platform: "linkedin", display_name: member.name,
      notes: "손 등록 메모", login_id: "manual-id", profile_url: "https://example.test/manual")
    @account.update!(notes: "점검 메모", profile_url: "https://example.test/found", session_status: "logged_in")
    snapshot = @account.profile_snapshots.create!(captured_at: Time.current)

    assert_difference "ProfileAccount.count", -1 do
      patch pd_profile_account_path(@account), params: {
        profile_account: { member_id: member.id }, link: "1", replace_id: manual.id
      }
    end

    assert_response :see_other
    assert_redirected_to pd_member_path(member, anchor: "accounts")
    assert_equal "LinkedIn 계정을 점검이 찾은 계정으로 바꿨습니다. 손으로 등록한 계정은 지우고 메모는 옮겼습니다.", flash[:notice]
    assert_equal @account, member.profile_accounts.where(platform: "linkedin").sole
    assert_equal "점검 메모\n손 등록 메모", @account.reload.notes
    assert_equal "manual-id", @account.login_id
    assert_equal "https://example.test/found", @account.profile_url
    assert_equal snapshot, @account.latest_snapshot
    get slug_admin_dashboard_path(slug: member.slug)
    assert_response :ok
    assert_select "#profile-accounts-status article", text: /LinkedIn.*관리 중/m, count: 1 do
      assert_select "li", text: /○ 계정 확인/, count: 0
    end
  end

  test "운영자는 기존 로그인 아이디를 유지하고 빈 주소를 손 등록 계정에서 옮긴다" do
    sign_in AdminUser.create!(email: "replace-admin@example.test", password: "password123", role: "admin")
    member = Member.create!(name: "교체 회원", email: "replace@example.test", slug: "replace")
    manual = member.profile_accounts.create!(platform: "linkedin", display_name: member.name,
      login_id: "manual-id", profile_url: "https://example.test/manual")
    @account.update!(login_id: "checked-id", notes: "점검 메모")

    patch pd_profile_account_path(@account), params: {
      profile_account: { member_id: member.id }, link: "1", replace_id: manual.id
    }

    assert_response :see_other
    assert_equal @account, member.profile_accounts.sole
    assert_equal "checked-id", @account.reload.login_id
    assert_equal "https://example.test/manual", @account.profile_url
    assert_equal "점검 메모", @account.notes
  end

  test "기록이 있는 손 등록 계정은 바꾸지 않는다" do
    member = Member.create!(name: "기록 회원", email: "history@example.test", slug: "history")
    manual = member.profile_accounts.create!(platform: "linkedin", display_name: member.name)
    snapshot = manual.profile_snapshots.create!(captured_at: Time.current)

    assert_no_difference "ProfileAccount.count" do
      patch pd_profile_account_path(@account), params: {
        profile_account: { member_id: member.id }, link: "1", replace_id: manual.id
      }
    end

    assert_response :see_other
    assert_redirected_to pd_member_path(member, anchor: "accounts")
    assert_equal "이 계정에는 이미 점검 기록이나 작성한 내용이 있어 바꿀 수 없어요.", flash[:alert]
    assert_nil @account.reload.member_id
    assert_equal member, manual.reload.member
    assert_equal snapshot, manual.latest_snapshot
  end

  test "다른 회원의 계정을 replace_id 로 보내면 거부한다" do
    member = Member.create!(name: "요청 회원", email: "request@example.test", slug: "request")
    other = Member.create!(name: "다른 회원", email: "other-manual@example.test", slug: "other-manual")
    manuals = [
      other.profile_accounts.create!(platform: "linkedin", display_name: other.name),
      member.profile_accounts.create!(platform: "naver_people", display_name: member.name),
      member.profile_accounts.create!(platform: "linkedin", display_name: member.name, tenant_id: 2)
    ]

    manuals.each do |manual|
      assert_no_difference "ProfileAccount.count" do
        patch pd_profile_account_path(@account), params: {
          profile_account: { member_id: member.id }, link: "1", replace_id: manual.id
        }
      end
      assert_response :see_other
      assert_redirected_to pd_member_path(member, anchor: "accounts")
      assert_equal "이 계정에는 이미 점검 기록이나 작성한 내용이 있어 바꿀 수 없어요.", flash[:alert]
      assert_nil @account.reload.member_id
    end
  end

  test "이미 연결된 찾은 계정은 바꾸기를 거부하고 손 등록 계정을 남긴다" do
    member = Member.create!(name: "요청 회원", email: "request@example.test", slug: "request")
    other = Member.create!(name: "기존 회원", email: "linked@example.test", slug: "linked")
    manual = member.profile_accounts.create!(platform: "linkedin", display_name: member.name)
    channel = member.ensure_personal_brand!.brand_channels.create!(platform: "naver_blog", profile_account_id: manual.id)
    @account.update!(member: other)

    assert_no_difference "ProfileAccount.count" do
      patch pd_profile_account_path(@account), params: {
        profile_account: { member_id: member.id }, link: "1", replace_id: manual.id
      }
    end

    assert_response :see_other
    assert_redirected_to pd_member_path(member, anchor: "accounts")
    assert_equal "이미 다른 회원에게 연결된 계정이에요.", flash[:alert]
    assert_equal other, @account.reload.member
    assert_equal member, manual.reload.member
    assert_equal manual.id, channel.reload.profile_account_id
  end

  test "찾은 계정으로 바꾸면 손 등록 계정을 가리키던 채널 연결을 찾은 계정으로 옮긴다" do
    member = Member.create!(name: "교체 회원", email: "replace-channel@example.test", slug: "replace-channel")
    other = Member.create!(name: "다른 회원", email: "other-channel@example.test", slug: "other-channel")
    manual = member.profile_accounts.create!(platform: "linkedin", display_name: member.name)
    channel = member.ensure_personal_brand!.brand_channels.create!(platform: "naver_blog", profile_account_id: manual.id)
    other_channel = other.ensure_personal_brand!.brand_channels.create!(platform: "naver_blog")
    other_channel.update_column(:profile_account_id, manual.id)

    patch pd_profile_account_path(@account), params: {
      profile_account: { member_id: member.id }, link: "1", replace_id: manual.id
    }

    assert_response :see_other
    assert_equal @account.id, channel.reload.profile_account_id
    assert_predicate channel, :valid?
    assert_nil other_channel.reload.profile_account_id
    assert_not BrandChannel.exists?(profile_account_id: manual.id)
  end

  test "예약 글이 가리키는 손 등록 계정은 바꾸지 않는다" do
    member = Member.create!(name: "예약 회원", email: "scheduled-replace@example.test", slug: "scheduled-replace")
    manual = member.profile_accounts.create!(platform: "linkedin", display_name: member.name)
    post = SnsScheduledPost.create!(profile_account: manual, platform: "linkedin", message: "글",
      scheduled_at: 1.day.from_now, status: "scheduled")

    assert_no_difference ["ProfileAccount.count", "SnsScheduledPost.count"] do
      patch pd_profile_account_path(@account), params: {
        profile_account: { member_id: member.id }, link: "1", replace_id: manual.id
      }
    end

    assert_response :see_other
    assert_equal "이 계정에는 이미 점검 기록이나 작성한 내용이 있어 바꿀 수 없어요.", flash[:alert]
    assert_equal manual.id, post.reload.profile_account_id
    assert_nil @account.reload.member_id
  end

  test "기존 계정을 연결하면 계정 수를 유지하고 회원 화면으로 돌아간다" do
    member = Member.create!(name: "계정 연결 회원", email: "profile-connect@example.test", slug: "profile-connect")

    assert_no_difference "ProfileAccount.count" do
      patch pd_profile_account_path(@account), params: {
        profile_account: { member_id: member.id }, link: "1"
      }
    end

    assert_response :see_other
    assert_redirected_to pd_member_path(member, anchor: "accounts")
    assert_equal "LinkedIn 계정을 #{member.name} 회원에 연결했습니다.", flash[:notice]
    assert_equal member, @account.reload.member
    follow_redirect!
    assert_select "#accounts a[href=?]", pd_profile_account_path(@account), text: "계정 상세"
  end

  test "대행 등록 복귀값 없이 계정을 수정하면 계정 상세로 이동한다" do
    patch pd_profile_account_path(@account), params: { profile_account: { display_name: "수정한 계정" } }

    assert_redirected_to pd_profile_account_path(@account)
    assert_equal "수정한 계정", @account.reload.display_name
  end

  test "계정 목록과 상세에서 연결된 회원으로 이동할 수 있다" do
    member = Member.create!(name: "계정 연결 회원", email: "profile-linked-member@example.test", slug: "profile-linked")
    @account.update!(member: member)

    get pd_profile_accounts_path
    assert_response :ok
    assert_select "td a[href=?]", pd_member_path(member), text: member.name

    get pd_profile_account_path(@account)
    assert_response :ok
    assert_select "a[href=?]", pd_member_path(member), text: "이 회원 대행 등록 현황"
    assert_select "a[href=?]", slug_admin_dashboard_path(slug: member.slug), text: "회원 화면에서 확인"
  end

  test "미연결 계정에만 회원 지정 링크를 표시한다" do
    member = Member.create!(name: "연결 회원", email: "linked-account@example.test", slug: "linked-account")
    linked = member.profile_accounts.create!(platform: "linkedin", display_name: "연결 계정")

    get pd_profile_accounts_path
    assert_response :ok
    assert_select "td", text: /미연결/ do
      assert_select "a[href=?]", edit_pd_profile_account_path(@account), text: "회원 지정", count: 1
    end
    assert_select "td a[href=?]", pd_member_path(member), text: member.name, count: 1
    assert_select "td a[href=?]", edit_pd_profile_account_path(linked), count: 0
  end

  test "weekly report renders both platforms and the date form" do
    travel_to Time.utc(2026, 11, 23, 15, 30)
    @account.profile_snapshots.create!(captured_at: Time.current, data: {
      "pages" => { "dashboard" => { "text" => file_fixture("linkedin/dashboard.txt").read } }
    })
    account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물")
    account.profile_snapshots.create!(captured_at: Time.current, data: { "people" => { "name" => "가상 인물" } })

    get weekly_report_pd_profile_accounts_path

    assert_response :success
    assert_select "h1", text: "인물정보 주간 리포트 2026-11-18 ~ 2026-11-24"
    assert_select "input[type=date][name=week_end][value='2026-11-24']"
    assert_select "h2", text: "LinkedIn"
    assert_select "h2", text: "네이버 인물정보"
    assert_select "td", text: "26"
    assert_select "p", text: "이번 주 게시물이 없습니다."
    assert_select "p", text: "이번 주 변경이 없습니다."
    assert_select "a", text: "다음 주", count: 0
  end

  test "weekly report links to dates seven days away" do
    travel_to Time.utc(2026, 11, 23, 15, 30)
    get weekly_report_pd_profile_accounts_path, params: { week_end: "2026-11-17" }

    assert_response :success
    assert_select "h1", text: "인물정보 주간 리포트 2026-11-11 ~ 2026-11-17"
    assert_select "a[href=?]", weekly_report_pd_profile_accounts_path(week_end: "2026-11-10"), text: "이전 주"
    assert_select "a[href=?]", weekly_report_pd_profile_accounts_path(week_end: "2026-11-24"), text: "다음 주"
    assert_select "p", text: "이 기간의 사본이 없습니다."
  end

  test "weekly report renders account cards as siblings after a card without snapshots" do
    travel_to Time.utc(2026, 11, 23, 15, 30)
    %w[linkedin naver_people].each do |platform|
      ProfileAccount.create!(platform: platform, display_name: "A 사본 없음")
      account = ProfileAccount.create!(platform: platform, display_name: "Z 사본 있음")
      account.profile_snapshots.create!(captured_at: Time.current, data: { "people" => {}, "pages" => {} })
    end

    get weekly_report_pd_profile_accounts_path

    assert_response :success
    assert_select "section > section > section", count: 0
    assert_select "section > section > p", text: "이 기간의 사본이 없습니다.", count: 3
    assert_select "section > section > h3", text: "Z 사본 있음", count: 2
  end

  test "weekly report falls back to Seoul today for invalid dates" do
    travel_to Time.utc(2026, 11, 23, 15, 30)
    [ "2026-02-30", "2026-1-01", "2026-11-25", "2019-12-31", "잘못된 날짜", [ "2026-11-17" ] ].each do |value|
      get weekly_report_pd_profile_accounts_path, params: { week_end: value }

      assert_response :success
      assert_select "h1", text: "인물정보 주간 리포트 2026-11-18 ~ 2026-11-24"
    end
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

  test "naver displays search exposure, history, comparison and namesakes" do
    account = ProfileAccount.create!(platform: "naver_people", display_name: "강승식")
    query = "강승식 가가호호"
    older = { "dss" => 42140857, "search" => { "results" => [ { "query" => query, "main" => nil } ] } }
    current = {
      "dss" => 42140857,
      "people" => { "name" => "강승식", "peopleOffice" => [ { "name" => "이전 회사" } ] },
      "search" => {
        "checked_at" => "2026-11-24T12:00:00Z",
        "results" => [
          { "query" => query, "main" => { "os" => "42140857", "name" => "강승식", "profile_text" => "소속\n가가호호" } },
          { "query" => "강승식", "main" => { "os" => "4058035", "name" => "강승식", "job" => "가수" },
            "same_name" => [ { "os" => "42140857" }, { "os" => "459417", "name" => "강승식", "details" => [ "교육자", "1964" ] } ] },
          { "query" => "강승식 기업인", "error" => "시간 초과" }
        ]
      }
    }
    account.profile_snapshots.create!(captured_at: 2.days.ago, data: {})
    account.profile_snapshots.create!(captured_at: 1.day.ago, data: older)
    account.profile_snapshots.create!(captured_at: Time.current, data: current)

    get pd_profile_account_path(account)

    assert_response :success
    assert_select "#naver-search-exposure" do
      assert_select "h2", text: "검색 노출"
      assert_select "p", text: /마지막 검색 점검/
      assert_select "a", text: query
      assert_select "td", text: "동명이인 목록에만"
      assert_select "td", text: "강승식 · 가수"
      assert_select "td", text: "오류 (시간 초과)"
      assert_select "li", text: "#{query} · 안 나옴 → 대표 박스로 노출"
      assert_select "td", text: "● 대표 박스로 노출"
      assert_select "td", text: "– 미수집"
      assert_select "h3", text: "검색 화면 vs 본인참여 대조"
      assert_select "tr.bg-amber-50 td", text: "다름"
      assert_select "h3", text: "같은 이름 다른 인물"
      assert_select "li", text: /강승식 · 교육자 · 1964/
      assert_select "a[href*='os=459417']", text: "os=459417"
      assert_select "a[href*='os=42140857']", count: 0
    end
  end

  test "naver search queries can be saved and cleared before a snapshot exists" do
    account = ProfileAccount.create!(platform: "naver_people", display_name: "강승식")
    get pd_profile_account_path(account)
    assert_select "p", text: "다음 점검부터 검색 노출을 기록합니다."
    assert_select "p", text: /기본 검색어/
    assert_select "form[action=?] textarea[name=search_queries]", search_queries_pd_profile_account_path(account)

    patch search_queries_pd_profile_account_path(account), params: { search_queries: " 강승식   가가호호 \r\n강승식 가가호호\n\n강승식" }
    assert_response :see_other
    assert_redirected_to pd_profile_account_path(account)
    assert_equal "검색어를 저장했습니다. 다음 점검부터 적용됩니다.", flash[:notice]
    assert_equal [ "강승식 가가호호", "강승식" ], account.reload.search_query_list

    patch search_queries_pd_profile_account_path(account), params: { search_queries: "" }
    assert_response :see_other
    assert_empty account.reload.search_query_list
  end

  test "search query updates are rejected for linkedin accounts" do
    patch search_queries_pd_profile_account_path(@account), params: { search_queries: "강승식" }

    assert_response :unprocessable_entity
    assert_empty @account.reload.search_query_list
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

  test "linkedin show displays the newsletter section and account drafts" do
    draft = @account.linkedin_newsletter_drafts.create!(title: "앱에 저장한 초안")
    get pd_profile_account_path(@account)
    assert_response :success
    assert_select "p", text: "다음 점검부터 뉴스레터를 모읍니다."

    url = "https://www.linkedin.com/newsletters/ximtier-dev-notes-7513833935739547648/"
    subscriber_url = "https://www.linkedin.com/newsletters/목표를-달성하는-협업의-힘-7018115202437054464/"
    edition_links = JSON.parse(file_fixture("linkedin/newsletter_page_links.json").read)
    @account.profile_snapshots.create!(captured_at: Time.current, data: {
      "pages" => {
        "newsletters" => { "text" => file_fixture("linkedin/newsletters.txt").read, "links" => [ url, subscriber_url ] },
        "newsletter_pages" => [ { "url" => url, "text" => file_fixture("linkedin/newsletter_page.txt").read, "links" => edition_links } ]
      }
    })
    get pd_profile_account_path(@account)

    assert_response :success
    assert_select "h2", text: "LinkedIn 뉴스레터"
    assert_select "h3", text: "구독자 날짜별 추이"
    assert_select "a[href=?][target=_blank]", url.delete_suffix("/"), text: "XimTier Dev Notes"
    assert_select "a[href=?]", edition_links.first
    assert_select "#newsletter-drafts" do
      assert_select "h2", text: "뉴스레터 글 초안"
      assert_select "p", text: "앱에 저장한 초안"
      assert_select "a[href=?]", edit_pd_profile_account_newsletter_draft_path(@account, draft)
      assert_select "select option", text: "XimTier Dev Notes"
      assert_select "select option", text: "목표를 달성하는 협업의 힘", count: 0
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
