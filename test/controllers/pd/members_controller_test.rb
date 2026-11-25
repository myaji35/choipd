require "test_helper"

class Pd::MembersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @pd = AdminUser.create!(email: "pd-members@example.test", password: "password123", role: "pd")
    @member = Member.create!(name: "대행 등록 회원", email: "pd-member@example.test", slug: "pd-member", status: "approved")
  end

  test "로그인이 필요하다" do
    get pd_members_path
    assert_redirected_to new_admin_user_session_path
    get pd_member_path(@member)
    assert_redirected_to new_admin_user_session_path
  end

  test "PD가 회원 목록을 검색할 수 있다" do
    other = Member.create!(name: "다른 회원", email: "pd-other@example.test", slug: "pd-other")
    sign_in @pd

    get pd_members_path
    assert_response :ok
    assert_select "h1", text: "회원 대행 등록"
    assert_select "li strong", text: @member.name
    assert_select "a[href=?]", pd_member_path(@member), text: "등록·확인"
    assert_select "a[href=?]", pd_member_path(other), text: "등록·확인"

    get pd_members_path, params: { q: @member.email }
    assert_response :ok
    assert_select "a[href=?]", pd_member_path(@member), text: "등록·확인"
    assert_select "a[href=?]", pd_member_path(other), count: 0
  end

  test "계정과 채널이 없는 회원의 플랫폼별 등록 링크를 보여 준다" do
    sign_in @pd
    get pd_member_path(@member)

    assert_response :ok
    assert_select "#consent-request-text", count: 0
    assert_select "a", text: "회원 화면에서 보기", count: 0
    assert_select "#accounts a.bg-primary", text: "계정 등록", count: 2
    ProfileAccount::PLATFORMS.each_key do |platform|
      assert_select "a[href=?]", new_pd_profile_account_path(member_id: @member.id, platform: platform), text: "계정 등록"
    end
    assert_select "#channels a.bg-primary", text: "채널 등록", count: 3
    MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.each_key do |platform|
      assert_select "a[href=?]", new_pd_member_channel_path(@member, platform: platform), text: "채널 등록"
    end
    assert_select "a[href=?]", slug_admin_dashboard_path(slug: @member.slug), text: "회원 화면에서 확인"
  end

  test "대행 등록 화면 맨 위에 남은 등록 수를 요약한다" do
    sign_in @pd
    get pd_member_path(@member)
    assert_select "#registration-summary", text: "프로필 계정 0/2 · 채널 0/3 등록"

    account = @member.profile_accounts.create!(platform: "naver_people", display_name: @member.name)
    @member.profile_accounts.create!(platform: account.platform, display_name: "같은 종류의 계정")
    brand = @member.ensure_personal_brand!
    channel = brand.brand_channels.create!(platform: "naver_blog")
    get pd_member_path(@member)
    assert_select "#registration-summary", text: "프로필 계정 1/2 · 채널 1/3 등록 · 위탁 동의 대기 1개"

    @member.profile_accounts.create!(platform: "linkedin", display_name: @member.name)
    channel.update!(delegation_consent_at: Time.current)
    (MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.keys - [channel.platform]).each do |platform|
      brand.brand_channels.create!(platform: platform, delegation_consent_at: Time.current)
    end
    get pd_member_path(@member)
    assert_select "#registration-summary", text: "등록을 모두 마쳤습니다."
  end

  test "등록된 계정마다 다음에 할 일을 알려 준다" do
    sign_in @pd
    account = @member.profile_accounts.create!(platform: "linkedin", display_name: @member.name)
    messages = {
      "unknown" => "아직 점검 전입니다. 점검을 돌리면 회원 화면의 '계정 확인'이 채워집니다.",
      "logged_out" => "로그인이 풀려 있습니다. ego 브라우저에서 다시 로그인한 뒤 점검해 주세요.",
      "error" => "점검 중 오류가 났습니다. 계정 상세에서 내용을 확인해 주세요.",
      "logged_in" => "계정 확인까지 끝났습니다. 다음은 계정 상세에서 내용 손보기입니다."
    }

    messages.each do |status, message|
      account.update!(session_status: status)
      get pd_member_path(@member)
      assert_select "#accounts li p", text: /#{Regexp.escape(message)}/
      assert_select "#accounts a[href=?]", pd_profile_accounts_path,
        text: "점검하러 가기", count: %w[unknown logged_out].include?(status) ? 1 : 0
    end

    account.profile_snapshots.create!(captured_at: Time.current)
    get pd_member_path(@member)
    assert_select "#accounts li p", text: "관리 중 — 회원 화면에도 '관리 중'으로 보입니다."
  end

  test "등록 전 플랫폼에는 같은 테넌트의 미연결 계정만 표시한다" do
    account = ProfileAccount.create!(platform: "linkedin", display_name: "점검 계정",
      login_id: "checked@example.test", session_status: "logged_in", tenant_id: @member.tenant_id)
    other = Member.create!(name: "다른 회원", email: "linked-other@example.test", slug: "linked-other")
    linked = other.profile_accounts.create!(platform: "linkedin", display_name: "연결된 계정")
    foreign = ProfileAccount.create!(platform: "linkedin", display_name: "다른 테넌트 계정", tenant_id: 2)
    sign_in @pd

    get pd_member_path(@member)

    assert_select "#accounts li p", text: "점검 계정 · checked@example.test · 로그인됨"
    assert_select "#accounts details form[action=?][method=post]", pd_profile_account_path(account) do
      assert_select "input[name='_method'][value=patch]"
      assert_select "input[name='profile_account[member_id]'][value=?]", @member.id.to_s
      assert_select "input[name=link][value=1]"
      assert_select "button", text: "이 회원에 연결"
    end
    [linked, foreign].each do |excluded|
      assert_select "#accounts li", text: /#{excluded.display_name}/, count: 0
      assert_select "#accounts form[action=?]", pd_profile_account_path(excluded), count: 0
    end

    @member.profile_accounts.create!(platform: "linkedin", display_name: "회원의 LinkedIn")
    get pd_member_path(@member)

    assert_select "#accounts form[action=?]", pd_profile_account_path(account), count: 0
  end

  test "미연결 계정은 플랫폼별로 5개까지만 표시하고 목록을 안내한다" do
    6.times do |index|
      ProfileAccount.create!(platform: "linkedin", display_name: "점검 계정 #{index + 1}")
    end
    sign_in @pd

    get pd_member_path(@member)

    assert_select "#accounts details:not([open]) summary", text: "이름이 다른 미연결 계정 6개 보기"
    assert_select "#accounts details button", text: "이 회원에 연결", count: 5
    assert_select "#accounts li", text: /점검 계정 6/, count: 0
    assert_select "#accounts a[href=?]", pd_profile_accounts_path, text: "인물정보 계정"
  end

  test "운영자에게만 대행 등록 화면에 운영자 회원 상세 링크를 표시한다" do
    sign_in @pd
    get pd_member_path(@member)
    assert_select "a[href=?]", admin_member_path(@member), count: 0

    sign_out @pd
    sign_in AdminUser.create!(email: "admin-members@example.test", password: "password123", role: "admin")
    get pd_member_path(@member)
    assert_select "header a[href=?]", admin_member_path(@member), text: "운영자 회원 상세"
  end

  test "회원의 여러 브랜드에 등록된 채널을 개인 브랜드부터 보여 주고 동의 상태를 표시한다" do
    brand = @member.brands.create!(name: "브랜드")
    waiting = brand.brand_channels.create!(platform: "naver_blog", account_handle: "waiting")
    personal = @member.ensure_personal_brand!
    consented = personal.brand_channels.create!(
      platform: "naver_blog", account_handle: "consented", delegation_consent_at: Time.utc(2026, 11, 24, 16)
    )
    sign_in @pd

    get pd_member_path(@member)
    assert_response :ok
    assert_select "#channels li", text: /운영 위탁 동의 대기/ do
      assert_select "a[href=?]", edit_pd_member_channel_path(@member, waiting)
    end
    assert_select "#channels li", text: /운영 위탁 동의함 · 2026\.11\.25/ do
      assert_select "a[href=?]", edit_pd_member_channel_path(@member, consented)
    end
    assert_select "#channels li:first-child", text: /consented/
  end

  test "등록과 동의 상태로 검색 결과를 걸러 보고 각 회원 수를 표시한다" do
    waiting = Member.create!(name: "필터 대기", email: "filter-waiting@example.test", slug: "filter-waiting")
    empty = Member.create!(name: "필터 등록 전", email: "filter-empty@example.test", slug: "filter-empty")
    ProfileAccount::PLATFORMS.each_key { |platform| @member.profile_accounts.create!(platform: platform, display_name: @member.name) }
    brand = @member.ensure_personal_brand!
    MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.each_key do |platform|
      brand.brand_channels.create!(platform: platform, delegation_consent_at: Time.current)
    end
    waiting.ensure_personal_brand!.brand_channels.create!(platform: "naver_blog")
    sign_in @pd

    get pd_members_path, params: { filter: "unexpected" }
    assert_select "a[aria-current=true]", text: "전체 3"
    assert_select "a[href=?]", pd_members_path(filter: "todo"), text: "등록 남음 2"
    assert_select "a[href=?]", pd_members_path(filter: "consent"), text: "위탁 동의 대기 1"
    assert_select "li", text: /#{@member.name}.*등록 완료/m
    assert_select "li", text: /#{waiting.name}.*동의 대기 1/m
    assert_select "li strong", text: empty.name

    get pd_members_path, params: { filter: "todo" }
    assert_select "li strong", count: 2
    assert_select "li strong", text: waiting.name
    assert_select "li strong", text: empty.name

    get pd_members_path, params: { filter: "consent", q: "필터" }
    assert_select "li strong", count: 1, text: waiting.name
    assert_select "li strong", text: empty.name, count: 0
    assert_select "input[name=filter][value=consent]"
    assert_select "a[href=?]", pd_members_path(q: "필터"), text: "전체 2"
    assert_select "a[href=?][aria-current=true]", pd_members_path(q: "필터", filter: "consent"), text: "위탁 동의 대기 1"

    get pd_members_path, params: { filter: "consent", q: empty.slug }
    assert_select "p", text: "위탁 동의를 기다리는 회원이 없습니다."
    get pd_members_path, params: { filter: "todo", q: @member.slug }
    assert_select "p", text: "등록이 남은 회원이 없습니다."
  end

  test "동의 대기 채널 안내와 등록한 계정 및 채널 바로가기를 표시한다" do
    @member.profile_accounts.create!(platform: "linkedin", display_name: @member.name)
    brand = @member.ensure_personal_brand!
    waiting = brand.brand_channels.create!(platform: "naver_blog")
    consented = brand.brand_channels.create!(platform: "facebook_page", delegation_consent_at: Time.current)
    sign_in @pd

    get pd_member_path(@member)
    assert_select "#channels h3", text: "위탁 동의 대기 1개 — 회원에게 알려 주세요"
    assert_select "textarea#consent-request-text[readonly][rows=5]" do |elements|
      assert_equal [
        "#{@member.name}님, imPD 운영팀입니다.",
        "네이버 블로그 채널 등록을 마쳤습니다.",
        "아래 주소로 로그인한 뒤 채널마다 '동의하러 가기'를 눌러 운영 위탁에 동의해 주세요.",
        "동의하시기 전에는 글을 올리지 않습니다.",
        slug_admin_channels_url(slug: @member.slug)
      ].join("
"), elements.first.text
    end
    assert_select "#channels [data-controller='clipboard-copy'] textarea#consent-request-text[data-clipboard-copy-target='source']"
    assert_select "#channels button[type=button][data-action='clipboard-copy#copy']", text: "안내 복사"
    assert_select "#channels [role=status][data-clipboard-copy-target='status']"
    assert_select "#channels button[onclick]", count: 0
    assert_select "#accounts a[href=?]", slug_admin_dashboard_path(slug: @member.slug, anchor: "profile-accounts-status"), text: "회원 화면에서 보기"
    [waiting, consented].each do |channel|
      assert_select "#channels a[href=?]", slug_admin_channels_path(slug: @member.slug, anchor: "channel-#{channel.id}"), text: "회원 화면에서 보기"
    end
    assert_select "#accounts a", text: "회원 화면에서 보기", count: 1
    assert_select "#channels a", text: "회원 화면에서 보기", count: 2

    waiting.update!(delegation_consent_at: Time.current)
    get pd_member_path(@member)
    assert_select "#consent-request-text", count: 0
  end

  test "로그인할 수 없는 회원은 목록과 상세에서 상태를 알려 준다" do
    pending = Member.create!(name: "승인 대기 회원", email: "pd-pending@example.test", slug: "pd-pending", status: "pending_approval")
    pending.ensure_personal_brand!.brand_channels.create!(platform: "naver_blog")
    Member.create!(name: "정지 회원", email: "pd-suspended@example.test", slug: "pd-suspended", status: "suspended")
    Member.create!(name: "거부 회원", email: "pd-rejected@example.test", slug: "pd-rejected", status: "rejected")
    Member.create!(name: "탈퇴 회원", email: "pd-withdrawn@example.test", slug: "pd-withdrawn", status: "approved", withdrawn_at: Time.current)
    sign_in @pd

    get pd_members_path
    assert_response :ok
    assert_select "li", text: /#{pending.name}/ do
      assert_select "span", text: "승인 대기 · 로그인 불가"
    end
    assert_select "li", text: /#{@member.name}/ do
      assert_select "span", text: /로그인 불가/, count: 0
    end
    %w[정지 거부 탈퇴].each do |status|
      assert_select "span", text: "#{status} · 로그인 불가"
    end

    get pd_member_path(pending)
    assert_response :ok
    assert_select "header [role=note] h2", text: "이 회원은 지금 로그인할 수 없습니다 (승인 대기)"
    assert_select "header [role=note] p", text: "승인·정지 해제는 운영자에게 요청해 주세요."
    assert_select "#channels h3", text: "위탁 동의 대기 1개"
    assert_select "#consent-request-text, #channels [data-controller='clipboard-copy']", count: 0
    assert_select "#channels p", text: "회원이 로그인할 수 있게 된 뒤에 동의 안내를 보낼 수 있습니다."
    assert_select "a[href^='/admin']", count: 0

    sign_in AdminUser.create!(email: "pending-member-admin@example.test", password: "password123", role: "admin")
    get pd_member_path(pending)
    assert_response :ok
    assert_select "a[href=?]", admin_member_path(pending), text: "운영자 회원 상세에서 상태 바꾸기"
  end

  test "이름이나 로그인 아이디가 맞는 미연결 계정만 바로 보여 준다" do
    @member.update!(name: "홍길동")
    same_name = ProfileAccount.create!(platform: "naver_people", display_name: "홍 길동 (공식)")
    other = ProfileAccount.create!(platform: "naver_people", display_name: "점검 계정")
    matches_email = ProfileAccount.create!(platform: "linkedin", display_name: "다른 이름", login_id: @member.email.upcase)
    matches_prefix = ProfileAccount.create!(platform: "linkedin", display_name: "또 다른 이름", login_id: @member.email.split("@").first.upcase)
    sign_in @pd

    get pd_member_path(@member)

    [same_name, matches_email, matches_prefix].each do |account|
      assert_select "#accounts form[action=?] button", pd_profile_account_path(account), text: "이 회원에 연결"
      assert_select "#accounts details form[action=?]", pd_profile_account_path(account), count: 0
    end
    assert_select "#accounts details:not([open]) summary", text: "이름이 다른 미연결 계정 1개 보기"
    assert_select "#accounts form[action=?]", pd_profile_account_path(other), count: 1
    assert_select "#accounts details form[action=?]", pd_profile_account_path(other) do |forms|
      assert_equal "점검 계정(아이디 없음) 계정을 홍길동 회원에 연결할까요? 연결한 뒤에는 이 화면에서 되돌릴 수 없습니다.", forms.first["data-turbo-confirm"]
    end
  end
end
