require "test_helper"

class MemberAdmin::ChannelsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    travel_to Time.find_zone!("Asia/Seoul").local(2026, 11, 25, 12)
    @member = Member.create!(name: "채널 회원", email: "channel-overview@example.com", slug: "channel-overview",
      status: "approved", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    @path = slug_admin_channels_path(slug: @member.slug)
  end

  test "채널이 없으면 세 채널 모두 등록 전 안내를 보여 준다" do
    get @path

    assert_response :ok
    assert_select "section.impd-card h2", count: 3 do |headings|
      assert_equal [ "네이버 블로그 등록 전", "페이스북 등록 전", "인스타그램 등록 전" ], headings.map(&:text)
    end
    assert_select "section.impd-card p", text: "등록은 운영자·PD에게 요청해 주세요.", count: 3
    assert_select "a[href^='/admin/brands']", count: 0
  end

  test "네이버 블로그에 올린 글·예약된 글·동의 상태를 보여 준다" do
    channel = create_channel("naver_blog", account_handle: "myblog", profile_url: "https://blog.naver.com/myblog",
      delegation_consent_at: seoul_time(10, 3), session_status: "connected",
      last_error: "운영자용 오류", credential_ref: "secret-label", ego_server_name: "ego-private", notes: "관리 메모")
    published_url = "https://blog.naver.com/myblog/1"
    SnsScheduledPost.create!(brand_channel: channel, platform: "naver_blog", title: "가을 보험 점검", message: "본문 앞부분입니다",
      status: "published", scheduled_at: seoul_time(11, 20), published_at: seoul_time(11, 20, 9, 30),
      published_url: published_url, result_message: "내부 결과")
    SnsScheduledPost.create!(brand_channel: channel, platform: "naver_blog", title: "다음 보험 점검", message: "다음 글입니다",
      status: "scheduled", scheduled_at: seoul_time(11, 27, 10))
    %w[draft publishing failed].each do |status|
      SnsScheduledPost.create!(brand_channel: channel, platform: "naver_blog", title: "숨길 글 #{status}", message: "숨길 본문",
        status: status, scheduled_at: seoul_time(11, 27))
    end

    get @path

    assert_response :ok
    [ "운영 중", "myblog", "가을 보험 점검", "2026.11.20 09:30에 올림", "2026.11.27 10:00에 올릴 예정", "✓ 운영 위탁 동의함 · 2026.10.03" ].each do |phrase|
      assert_includes response.body, phrase
    end
    assert_select "a[href=?]", published_url, text: "올라간 글 보기 ↗"
    assert_select "a[href=?]", edit_slug_admin_brand_brand_channel_path(slug: @member.slug, id: channel.id), text: "동의 내용 보기·바꾸기"
    [ "운영자용 오류", "secret-label", "ego-private", "내부 결과", "관리 메모", "미점검", "로그인 필요", "ego", "숨길 글" ].each do |phrase|
      assert_not_includes response.body, phrase
    end
    assert_select "a[href^='/admin/brands']", count: 0
  end

  test "페이스북은 연결된 계정의 글과 팔로워 변화를 보여 준다" do
    account = SnsAccount.create!(member: @member, platform: "facebook", account_name: "내 페이지")
    channel = create_channel("facebook_page", sns_account: account, delegation_consent_at: seoul_time(10, 3))
    SnsScheduledPost.create!(sns_account: account, platform: "facebook", message: "페이스북 글의 본문 앞부분",
      status: "published", scheduled_at: seoul_time(11, 20, 9, 30))
    account.sns_follower_snapshots.create!(follower_count: 100, captured_at: seoul_time(11, 19), source: "manual")
    account.sns_follower_snapshots.create!(follower_count: 112, captured_at: seoul_time(11, 20), source: "manual")

    get @path

    assert_response :ok
    assert_select "#channel-#{channel.id}" do
      assert_select "p", text: "페이스북 글의 본문 앞부분"
      assert_select "p", text: "2026.11.20 09:30에 올림"
      assert_select "p", text: /지금\s+112명\s*·\s*지난 기록보다 12명 늘었어요/
      assert_select "ul[style*='flex-wrap: wrap'] li", text: "11.20 112명"
      assert_select "ul[style*='flex-wrap: wrap'] li", text: "11.19 100명"
    end
  end

  test "동의 전 채널은 준비 중과 동의하러 가기를 보여 준다" do
    channel = create_channel("instagram")

    get @path

    assert_response :ok
    assert_select "#channel-#{channel.id}" do
      assert_select "span", text: "준비 중"
      assert_select "p", text: "아직 없어요. 운영팀이 첫 글을 올리거나 예약하면 여기에 보여요."
      assert_select "dl.channel-stat-grid", count: 0
      assert_select "p", text: "○ 아직 동의하지 않았어요"
      assert_select "p", text: "운영 위탁에 동의하면 운영팀이 글을 올리기 시작해요."
      assert_select "a[href=?]", edit_slug_admin_brand_brand_channel_path(slug: @member.slug, id: channel.id), text: "동의하러 가기"
    end
  end

  test "글이 없는 준비 중 채널은 빈 숫자 상자 없이 한 문장으로 안내한다" do
    account = @member.sns_accounts.create!(platform: "instagram", account_name: "내 인스타그램")
    account.sns_follower_snapshots.create!(follower_count: 222, captured_at: seoul_time(11, 20), source: "manual")
    channel = create_channel("instagram", sns_account: account, delegation_consent_at: seoul_time(10, 3))

    get @path

    assert_response :ok
    assert_select "#channel-#{channel.id}" do |section|
      assert_select "h3", text: "팔로워 변화", count: 0
      assert_select "h3", text: "올린 글·예약된 글", count: 1
      assert_select "p", text: "아직 없어요. 운영팀이 첫 글을 올리거나 예약하면 여기에 보여요.", count: 1
      assert_select "dl.channel-stat-grid div", count: 1 do
        assert_select "dt", text: "팔로워"
        assert_select "dd", text: "222명"
      end
      assert_not_includes section.first.text, "0건"
    end
  end

  test "글이 없고 팔로워 기록이 두 개면 팔로워 변화를 빈 글 안내보다 먼저 보여 준다" do
    account = @member.sns_accounts.create!(platform: "instagram", account_name: "내 인스타그램")
    account.sns_follower_snapshots.create!(follower_count: 211, captured_at: seoul_time(11, 19), source: "manual")
    account.sns_follower_snapshots.create!(follower_count: 222, captured_at: seoul_time(11, 20), source: "manual")
    channel = create_channel("instagram", sns_account: account, delegation_consent_at: seoul_time(10, 3))

    get @path

    assert_response :ok
    assert_select "#channel-#{channel.id}" do |section|
      assert_select "dl.channel-stat-grid", count: 0
      assert_select "h3", text: "팔로워 변화", count: 1
      assert_select "strong", text: "222명", count: 1
      headings = section.first.css("h3").map(&:text)
      assert_equal [ "팔로워 변화", "올린 글·예약된 글" ], headings.first(2)
    end
  end

  test "운영 중 채널 숫자 상자는 네 개이고 마지막 글은 짧은 날짜로 보여 준다" do
    channel = create_channel("naver_blog", delegation_consent_at: seoul_time(10, 3))
    posted_at = seoul_time(11, 20, 9, 30)
    SnsScheduledPost.create!(brand_channel: channel, platform: "naver_blog", title: "올린 글", message: "본문",
      status: "published", scheduled_at: posted_at, published_at: posted_at)

    get @path

    assert_response :ok
    assert_select "#channel-#{channel.id} dl.channel-stat-grid" do
      assert_select "div", count: 4
      assert_select "dd[title='2026.11.20']", text: "11.20"
      assert_select "dd", text: "—"
      assert_select "dd", text: "아직 못 셌어요"
    end
    assert_match(/@media \(max-width: 768px\) \{\s*\.channel-stat-grid \{ grid-template-columns: repeat\(2, minmax\(0, 1fr\)\)/, response.body)
  end

  test "동의한 채널은 동의 안내를 한 줄로 줄이고 동의 전 채널은 그대로 보여 준다" do
    delegated = create_channel("naver_blog", delegation_consent_at: seoul_time(10, 3))
    pending = create_channel("facebook_page")

    get @path

    assert_response :ok
    assert_select "section.impd-card h3", text: "운영 위탁 동의", count: 1
    assert_select "#channel-#{delegated.id} p", text: "✓ 운영 위탁 동의함 · 2026.10.03 · 언제든 그만둘 수 있어요."
    assert_select "#channel-#{pending.id} h3", text: "운영 위탁 동의"
    assert_select "#channel-#{pending.id} a", text: "동의하러 가기"
  end

  test "팔로워 기록이 없으면 팔로워 변화 구역을 보이지 않는다" do
    blog = create_channel("naver_blog", delegation_consent_at: seoul_time(10, 3))
    facebook = create_channel("facebook_page")
    SnsScheduledPost.create!(brand_channel: blog, platform: "naver_blog", title: "블로그 글", message: "올린 글",
      status: "published", scheduled_at: seoul_time(11, 20))

    get @path

    assert_response :ok
    assert_select "section.impd-card h3", text: "팔로워 변화", count: 0
    assert_select "#channel-#{blog.id} dd", text: "아직 못 셌어요"
    note = "팔로워는 아직 못 셌어요. 운영팀이 세면 여기에 보여요."
    assert_select "#channel-#{blog.id} p", text: note, count: 0
    assert_select "#channel-#{facebook.id} p", text: note, count: 1
  end

  test "바로가기 버튼에 채널 상태를 함께 보여 준다" do
    blog = create_channel("naver_blog", delegation_consent_at: seoul_time(10, 3))
    create_channel("facebook_page")
    SnsScheduledPost.create!(brand_channel: blog, platform: "naver_blog", title: "블로그 글", message: "올린 글",
      status: "published", scheduled_at: seoul_time(11, 20))

    get @path

    assert_response :ok
    assert_select "nav[aria-label='채널 바로가기'] a[style*='min-height: 44px']", count: 2 do |links|
      assert_equal [ "네이버 블로그 · 운영 중", "페이스북 · 준비 중" ], links.map(&:text)
    end
  end

  test "연결에 문제가 있으면 확인 중으로만 알린다" do
    create_channel("instagram", session_status: "error", last_error: "토큰 만료 상세")

    get @path

    assert_response :ok
    assert_select "section span", text: "확인 중"
    assert_includes response.body, "계정 연결에 문제가 있어 운영팀이 확인하고 있어요. 따로 하실 일은 없어요."
    assert_not_includes response.body, "토큰 만료 상세"
  end

  test "운영자 대리 접속에서만 채널 수정 링크가 보인다" do
    channel = create_channel("naver_blog")
    management_path = edit_admin_brand_brand_channel_path(channel.brand, channel)
    consent_path = edit_slug_admin_brand_brand_channel_path(slug: @member.slug, id: channel.id)

    reset!
    sign_in AdminUser.create!(email: "channel-overview-admin@example.com", password: "password1234", role: "admin")
    get @path

    assert_response :ok
    assert_select "a[href=?]", management_path, text: "채널 수정 (운영자 화면)"
    assert_select "a[href=?]", new_admin_brand_brand_channel_path(channel.brand), text: "채널 등록 (운영자 화면)", count: 2
    assert_includes response.body, "동의는 회원 본인만 바꿀 수 있어요."
    assert_select "a[href=?]", consent_path, count: 0

    reset!
    sign_in AdminUser.create!(email: "channel-overview-pd@example.com", password: "password1234", role: "pd")
    get @path

    assert_response :ok
    assert_select "a[href^='/admin/brands']", count: 0
    assert_select "a[href=?]", consent_path, count: 0
    assert_includes response.body, "동의는 회원 본인만 바꿀 수 있어요."
  end

  test "다른 회원의 채널과 글은 보이지 않는다" do
    other = Member.create!(name: "다른 회원", email: "other-overview@example.com", slug: "other-overview")
    brand = other.brands.create!(name: "다른 브랜드")
    channel = brand.brand_channels.create!(platform: "naver_blog", account_handle: "other-blog", delegation_consent_at: seoul_time(10, 3))
    SnsScheduledPost.create!(brand_channel: channel, platform: "naver_blog", title: "남의 글", message: "남의 본문",
      status: "published", scheduled_at: seoul_time(11, 20))

    get @path

    assert_response :ok
    assert_not_includes response.body, "other-blog"
    assert_not_includes response.body, "남의 글"

    get slug_admin_channels_path(slug: other.slug)

    assert_response :redirect
  end

  test "로그인하지 않으면 회원 로그인으로 보낸다" do
    reset!
    get @path

    assert_redirected_to login_member_path(slug: @member.slug)
  end

  private

  def create_channel(platform, **attributes)
    brand = @member.brands.find_or_create_by!(name: "개인 브랜드", personal: true)
    brand.brand_channels.create!(platform: platform, **attributes)
  end

  def seoul_time(month, day, hour = 0, minute = 0)
    Time.find_zone!("Asia/Seoul").local(2026, month, day, hour, minute)
  end
end
