require "test_helper"

class MemberDashboardChannelsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    travel_to Time.find_zone!("Asia/Seoul").local(2026, 11, 25, 12)
    @member = Member.create!(
      name: "테스트 회원", email: "dashboard-channel@example.test", slug: "dashboard-channel",
      status: "approved", business_type: "individual", profession: "custom",
      password: "password1234", password_confirmation: "password1234"
    )
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    @path = slug_admin_dashboard_path(slug: @member.slug)
  end

  test "채널이 없으면 프로필과 방문 현황 사이에 세 채널의 등록 전 안내를 보여 준다" do
    get @path

    assert_response :ok
    assert_select "#channel-status" do
      assert_select "article", count: 3
      assert_select "article h3", count: 3 do |headings|
        assert_equal [ "네이버 블로그 등록 전", "페이스북 등록 전", "인스타그램 등록 전" ], headings.map(&:text)
      end
      assert_select "article p", text: /등록은 운영자·PD에게 요청해 주세요\./, count: 3
      assert_select "a[href=?]", slug_admin_channels_path(slug: @member.slug), text: "올린 글·예약된 글 모두 보기 →", count: 1
    end
    profile_position = response.body.index('id="profile-accounts-status"')
    channel_position = response.body.index('id="channel-status"')
    visits_position = response.body.index("최근 14일 방문")
    assert_operator profile_position, :<, channel_position
    assert_operator channel_position, :<, visits_position
  end

  test "운영 중인 채널의 최근 게시 건수와 예약 건수를 보여 준다" do
    brand = @member.brands.create!(name: "개인 브랜드", personal: true)
    channel = brand.brand_channels.create!(platform: "naver_blog", delegation_consent_at: 45.days.ago)
    [ 5.days.ago, 40.days.ago ].each do |posted_at|
      SnsScheduledPost.create!(brand_channel: channel, platform: "naver_blog", title: "올린 글", message: "본문",
        status: "published", scheduled_at: posted_at, published_at: posted_at)
    end
    SnsScheduledPost.create!(brand_channel: channel, platform: "naver_blog", title: "예약 글", message: "본문",
      status: "scheduled", scheduled_at: 2.days.from_now)

    get @path

    assert_response :ok
    assert_select "#channel-status" do |section|
      assert_select "article span", text: "운영 중"
      assert_select "dl div", text: /최근 30일 올린 글\s*1건/, count: 1
      assert_select "dl div", text: /예약된 글\s*1건 · 다음 글 11\.27/, count: 1
      assert_select "dl div", text: /마지막 글\s*11\.20/, count: 1
      assert_select "a[href=?]", slug_admin_channels_path(slug: @member.slug, anchor: "channel-#{channel.id}"), text: "자세히 보기"
      assert_not_includes section.first.text, "팔로워"
      assert_not_includes section.first.text, "따로 하실 일은 없어요"
    end
  end

  test "글을 올린 적 없는 준비 중 채널은 0건을 늘어놓지 않고 안내 문장과 팔로워만 보여 준다" do
    account = @member.sns_accounts.create!(platform: "facebook", account_name: "내 페이지")
    account.sns_follower_snapshots.create!(follower_count: 142, captured_at: Time.current, source: "manual")
    brand = @member.brands.create!(name: "개인 브랜드", personal: true)
    brand.brand_channels.create!(platform: "facebook_page", sns_account: account, delegation_consent_at: 1.day.ago)

    get @path

    assert_response :ok
    assert_select "#channel-status" do |section|
      assert_select "article p", text: /운영팀이 첫 글을 준비하고 있어요/
      assert_select "dl div", text: /팔로워\s*142명/, count: 1
      [ "0건", "아직 없어요", "최근 30일 올린 글" ].each do |phrase|
        assert_not_includes section.first.text, phrase
      end
    end
  end

  test "숫자 조각은 줄바꿈 금지 스타일을 가진다" do
    get @path

    assert_response :ok
    assert_includes response.body, ".channel-overview-facts > div { white-space: nowrap; }"
    assert_select "#channel-status article[style*='overflow-wrap: anywhere']", count: 0
  end

  test "회원 본인에게는 관리 링크를 숨기고 운영자에게 플랫폼별 등록 링크를 보여 준다" do
    get @path
    assert_response :ok
    assert_select "#channel-status a", text: "관리 화면에서 열기", count: 0

    reset!
    sign_in AdminUser.create!(email: "dashboard-channel-admin@example.test", password: "password1234", role: "admin")
    get @path

    assert_response :ok
    assert_select "#channel-status a", text: "관리 화면에서 열기", count: 3
    MemberAdmin::ChannelOverview::CHANNEL_PLATFORMS.each_key do |platform|
      assert_select "#channel-status a[href=?]", new_pd_member_channel_path(@member, platform: platform),
        text: "관리 화면에서 열기", count: 1
    end
  end

  test "PD 대리 접속에서는 세 채널 모두 PD 관리 화면으로 연결한다" do
    channel = @member.ensure_personal_brand!.brand_channels.create!(platform: "naver_blog")
    reset!
    sign_in AdminUser.create!(email: "dashboard-channel-pd@example.test", password: "password1234", role: "pd")
    get @path

    assert_response :ok
    assert_select "#channel-status a", text: "관리 화면에서 열기", count: 3 do |links|
      links.each do |link|
        assert link["href"].start_with?("/pd/members/")
        assert_not_includes link["href"], "/admin/brands"
      end
    end
    assert_select "#channel-status a[href=?]", edit_pd_member_channel_path(@member, channel), text: "관리 화면에서 열기"
  end
end
