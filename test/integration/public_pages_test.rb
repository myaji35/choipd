require "test_helper"

class PublicPagesTest < ActionDispatch::IntegrationTest
  test "homepage returns 200" do
    get root_path
    assert_response :success
    assert_select 'meta[property="og:title"][content=?]', "imPD — 1인 사업자·크리에이터의 홍보 페이지"
    assert_select 'meta[property="og:image"][content^=?]', "#{request.base_url}/assets/og-default"
    assert_select 'meta[property="og:image:width"][content="1200"]'
    assert_select 'meta[property="og:image:height"][content="630"]'
    assert_select 'meta[property="og:image:alt"][content]', count: 1
    assert_select 'meta[name="twitter:card"][content="summary_large_image"]'
    assert_select "title", text: "imPD — 1인 사업자·크리에이터의 홍보 페이지"
    assert_select 'a[href="#main-content"]', text: "본문 바로가기"
    assert_select "footer a[href=?]", new_inquiry_path, text: "문의하기"
    assert_select "a[href=?]", privacy_path, text: "개인정보처리방침", count: 1
  end

  test "homepage puts one offer in the hero and keeps the video and pricing in their sections" do
    get root_path

    assert_select "h1", text: "오래 활동해 온 크리에이터의 새 홍보 페이지", count: 1
    assert_select ".impd-hero-actions a", count: 2
    assert_select ".impd-topnav-actions a[href=?]", member_signup_path, text: "내 페이지 만들기"
    assert_select "#how a[data-promo-popup][href=?]", promo_watch_path, text: "홍보 영상 보기 (30초)"
    assert_select "#pricing a[href=?]", member_signup_path, text: "내 페이지 만들기", count: 1
    assert_select "#faq summary", count: 6
    assert_select '.impd-joinstrip, a[href="#signup"], .hero-phone-review, .hero-phone-caption', count: 0
    assert_select ".impd-frap-home", count: 1
    assert_select 'link[href="/fonts/impd-fonts.css?v=1"]', count: 1
    assert_select 'link[href*="fonts.googleapis.com"], link[href*="fonts.gstatic.com"], link[href*="cdn.jsdelivr.net"]', count: 0
  end

  test "homepage counts all public members beyond the featured cards" do
    7.times do |index|
      Member.create!(name: "공개 회원 #{index}", email: "taste-home-#{index}@example.com",
        slug: "taste-home-#{index}", status: "approved", password: "password1234")
    end
    Member.create!(name: "비공개 회원", email: "taste-private@example.com",
      slug: "taste-private", status: "pending_approval", password: "password1234")

    get root_path

    count = Member.for_tenant.publicly_visible.count
    assert_operator count, :>, 6
    assert_select "#people .impd-member-count", text: "지금 #{count}명이 운영 중"
    assert_select "#people .impd-member-grid > a", count: 6
  end

  test "member page has a profile share title" do
    member = Member.create!(name: "공유 회원", email: "og-#{SecureRandom.hex(4)}@example.com",
      slug: "og-#{SecureRandom.hex(4)}", status: "approved", password: "password1234")
    get "/#{member.slug}"
    assert_response :success
    assert_select 'meta[property="og:title"][content=?]', member.name
    assert_select 'meta[property="og:image"][content*="og-default"]'

    member.update!(profession: "educator")
    get "/#{member.slug}"
    assert_select 'meta[property="og:title"][content=?]', "#{member.name} · #{member.profession_label}"

    member.update!(profile_image: "https://example.com/profile.jpg")
    get "/#{member.slug}"
    assert_select 'meta[property="og:image"][content=?]', "https://example.com/profile.jpg", count: 1
  end

  test "static not found page offers a Korean recovery link" do
    html = Rails.public_path.join("404.html").read
    [ 'lang="ko"', "찾으시는 페이지가 없어요", 'href="/"', "처음 화면으로" ].each do |text|
      assert_includes html, text
    end
    assert_not_includes html, "The page you were looking for"
  end

  test "homepage CTAs reflect member session" do
    get root_path
    assert_select ".impd-hero-actions a.impd-btn-primary", text: /내 페이지 만들기/

    member = Member.create!(name: "회원", email: "home-#{SecureRandom.hex(4)}@example.com",
      slug: "home-#{SecureRandom.hex(4)}", status: "approved", password: "password1234")
    post login_member_post_path(slug: member.slug), params: { password: "password1234" }
    get root_path

    assert_response :success
    assert_select ".impd-hero-actions a.impd-btn-primary[href=?]", "/#{member.slug}/admin/dashboard", text: /내 페이지 관리/ do
      assert_select "i.lni-pencil-1"
    end
    assert_select ".impd-hero-actions", text: /내 페이지 만들기/, count: 0
    assert_select ".impd-hero-actions a[href=?]", "/#{member.slug}", text: /내 페이지 보기/
    assert_operator css_select("a[href='/#{member.slug}/admin/dashboard']").count { |link| link.text.include?("내 페이지 관리") }, :>=, 3
    assert_operator css_select("a[href='/#{member.slug}']").count { |link| link.text.include?("내 페이지 보기") }, :>=, 2
  end

  test "inquiry page returns 200" do
    get new_inquiry_path
    assert_response :success
  end

  test "education page returns 200" do
    get education_path
    assert_response :success
  end

  test "media page returns 200" do
    get media_path
    assert_response :success
  end

  test "works page returns 200" do
    get works_path
    assert_response :success
  end

  test "community page returns 200" do
    get community_path
    assert_response :success
  end

  test "chopd footer keeps inquiry entry and service links" do
    [ education_path, media_path, media_greeting_path, works_path, new_inquiry_path ].each do |path|
      get path
      assert_response :success

      assert_select "footer a[href=?]", new_inquiry_path, text: "B2B/B2G 문의하기"
      assert_select "footer a[href=?]", education_path, text: "교육 과정"
      assert_select "footer a[href=?]", media_path, text: "한국환경저널"
      assert_select "footer a[href=?]", works_path, text: "작품 갤러리"
      assert_select "footer a[href=?]", community_path, text: "커뮤니티"
      assert_select "footer a[href=?]", community_path, text: "뉴스레터 구독"
      assert_select "footer a[href=?]", education_path, text: "교육"
      assert_select "footer a[href=?]", media_path, text: "미디어"
      assert_select "footer a[href=?]", works_path, text: "작품"
      assert_select "footer a.whitespace-nowrap", minimum: 9
    end
  end

  test "impd layout pages do not render chopd footer" do
    [ root_path, community_path ].each do |path|
      get path
      assert_response :success
      assert_no_match(/최범희 PD 퍼스널 브랜드 플랫폼/, response.body)
    end
  end
  test "hero switches from the example to real public member pages and counts at ten" do
    members = 5.times.map { |index| public_card_member(index) }
    get root_path
    assert_select ".hero-phone", count: 1
    assert_select ".hero-phone-qr, .impd-flow-card, .impd-hero-fact .impd-count-up", count: 0

    members << public_card_member(5, slug: "na-seolgye", bio: nil)
    get root_path
    assert_select ".hero-phone-qr img[src='/qr/na-seolgye.svg']", count: 1
    members.last.update!(career_note: "직접 기록한 작업 경력")
    get root_path
    assert_select ".hero-phone", count: 0
    assert_select ".impd-flow-pause", count: 1
    assert_select ".impd-hero-fact .impd-count-up", count: 0
    assert_equal members.map(&:display_url).sort, css_select(".impd-flow a.impd-flow-card").map { |card| card["href"] }.sort
    assert_select ".impd-flow-card[href='/na-seolgye'] .impd-member-badge", text: "예시"

    (6...10).each { |index| public_card_member(index, profession: "educator") }
    get root_path
    count = Member.for_tenant.publicly_visible.count
    assert_select ".impd-hero-fact .impd-count-up", text: count.to_s
    assert_select ".impd-profession-pill[href*='realtor']", count: 0
    assert_equal count, css_select(".impd-profession-pill .impd-chip-count").sum { |chip| chip.text.to_i }
  end

  test "recent activity excludes profile photos and content from nonpublic members" do
    member = public_card_member(0)
    profile = attach_photo(member, "people")
    member.update!(profile_image: profile.display_url)
    photo = attach_photo(member, "workshop")
    member.member_posts.create!(title: "공개 소식", content: "본문", is_published: 1, published_at: Time.current)

    %w[pending_approval withdrawn].each_with_index do |status, index|
      hidden = public_card_member(index + 1, status: (status == "withdrawn" ? "approved" : status),
        withdrawn_at: (Time.current if status == "withdrawn"), name: "비공개 활동 #{index}")
      attach_photo(hidden, "daily")
      hidden.member_posts.create!(title: "비공개 소식 #{index}", content: "본문", is_published: 1, published_at: Time.current)
    end

    get root_path
    assert_response :success
    assert_select "#moments .impd-moment", count: 1
    assert_select "#moments .impd-moment-tall", count: 0
    assert_select "#moments img[src=?]", photo.thumbnail_url
    assert_select "#moments img[src=?]", profile.thumbnail_url, count: 0
    assert_select ".impd-news a[href=?]", "#{member.display_url}#posts", text: /공개 소식/
    assert_select ".impd-member-card[href=?] .impd-member-cover img[data-src=?]", member.display_url, photo.thumbnail_url
    assert_no_match(/비공개 활동|비공개 소식/, response.body)
  end

  test "home and explore SQL counts stay constant from six to eighteen members" do
    6.times { |index| attach_photo(public_card_member(index), "workshop") }
    paths = [root_path, explore_path]
    before = paths.map { |path| request_sql_count(path) }
    (6...18).each { |index| attach_photo(public_card_member(index), "workshop") }
    assert_equal before, paths.map { |path| request_sql_count(path) }
  end

  private

  def public_card_member(index, **attributes)
    Member.create!({ name: "활동 회원 #{index}", email: "flow-#{index}@example.com",
      slug: "flow-#{index}", status: "approved", password: "password1234",
      bio: "소개", profession: "custom" }.merge(attributes))
  end

  def attach_photo(member, category)
    member.member_photos.create!(category: category,
      image: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png"))
  end

  def request_sql_count(path)
    count = 0
    record = ->(*args) do
      payload = args.last
      count += 1 unless payload[:cached] || payload[:name] == "SCHEMA"
    end
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(record, "sql.active_record") { get path }
    end
    assert_response :success
    count
  end

end
