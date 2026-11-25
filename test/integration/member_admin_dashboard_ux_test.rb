require "test_helper"

class MemberAdminDashboardUxTest < ActionDispatch::IntegrationTest
  test "dashboard shows the next task and grouped navigation" do
    member = Member.create!(name: "테스트 회원", email: "dashboard-#{SecureRandom.hex(4)}@example.com", slug: "dashboard-#{SecureRandom.hex(4)}", status: "approved", business_type: "individual", profession: "custom", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: member.email, password: "password1234" }
    get slug_admin_dashboard_path(slug: member.slug)
    assert_response :success
    assert_includes response.body, "다음 할 일"
    assert_select "details summary", text: /준비 항목 \d+개 중 \d+개 마쳤어요 · 전체 보기/
    %w[내\ 페이지 고객 홍보].each { |heading| assert_includes response.body, heading }
    assert_not_includes response.body, "예시 페이지"
    assert_includes response.body, "아직 방문이 적어요"
  end

  test "휴대폰에서는 다음 할 일 바로 아래에 내 페이지 한눈에가 온다" do
    member = create_overview_member
    get slug_admin_dashboard_path(slug: member.slug)

    assert_response :ok
    assert_select ".dashboard-grid > .dashboard-main > section.dashboard-next"
    assert_select ".dashboard-grid > aside.dashboard-overview"
    assert_includes response.body, ".dashboard-main { display: contents; }"
    assert_includes response.body, ".dashboard-overview { order: 2;"
  end

  test "SNS 팔로워 집계를 기다리는 이유와 숫자 띠 바로가기를 보여 준다" do
    slug = "dashboard-#{SecureRandom.hex(4)}"
    member = Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug, status: "approved",
      business_type: "individual", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: member.email, password: "password1234" }

    get slug_admin_dashboard_path(slug: slug)

    assert_response :ok
    [ "SNS 팔로워", "준비 중", "운영팀이 SNS 계정을 연결하면 보여요" ].each do |text|
      assert_select ".dashboard-stats p", text: text
    end
    [ "총 추종자", "최신 집계", "총합", "QR·공유 누적", "프로필 사진 업로드", "최근 수집", "등록 정보" ].each do |text|
      assert_not_includes response.body, text
    end
    assert_select ".dashboard-stats a[href=?]", slug_admin_inquiries_path(slug: slug), text: "0"
    assert_select ".dashboard-stats a[href=?]", slug_admin_services_path(slug: slug), text: "0"
  end

  test "내 페이지 한눈에에서 주소와 빈 항목 안내를 보여 준다" do
    member = create_overview_member
    slug = member.slug
    get slug_admin_dashboard_path(slug: slug)

    assert_response :ok
    assert_select ".dashboard-overview" do |panels|
      assert_select "h2#page-overview-title", text: "내 페이지 한눈에"
      assert_select "p", text: "impd.townin.net/#{slug}"
      assert_select "a[href=?][target='_blank'][rel='noopener']", public_profile_path(slug: slug), text: "내 페이지 보기"
      assert_select "button[type='button']", text: "주소 복사"
      assert_select "a[href=?] .dashboard-overview-value", slug_admin_services_path(slug: slug), text: "아직 없어요 · 추가하기"
      assert_select "a[href=?] .dashboard-overview-value", slug_admin_inquiries_path(slug: slug), text: "없어요"
      assert_select "a[href=?] .dashboard-overview-value", slug_admin_posts_path(slug: slug), text: "아직 없어요 · 쓰기"
      assert_not_includes panels.first.text, "에디터"
    end
  end

  test "내 페이지 한눈에에서 항목별 개수와 확인할 건수를 보여 준다" do
    member = create_overview_member
    slug = member.slug
    member.member_services.create!([ { title: "상담" }, { title: "강의" } ])
    member.member_faqs.create!(question: "상담 시간은?", answer: "오전 10시부터입니다.")
    visible_post = member.member_posts.create!(title: "상담 안내", content: "상담 일정", is_published: 1)
    member.member_posts.create!(title: "준비 중", content: "다음 주 일정", is_published: 0)
    member.member_inquiries.create!(sender_name: "방문자", sender_email: "visitor@example.com", message: "상담을 요청합니다", is_read: 0)
    member.member_reviews.create!(reviewer_name: "고객", rating: 5, status: "new")
    member.member_bookings.create!(external_url: "https://example.com/reservations")
    get slug_admin_dashboard_path(slug: slug)

    assert_response :ok
    assert_select ".dashboard-overview" do
      {
        slug_admin_services_path(slug: slug) => "2개",
        slug_admin_faqs_path(slug: slug) => "1개",
        slug_admin_posts_path(slug: slug) => "보이는 글 1개",
        slug_admin_inquiries_path(slug: slug) => "1건",
        slug_admin_reviews_path(slug: slug) => "1건",
        slug_admin_bookings_path(slug: slug) => "1개"
      }.each do |path, value|
        assert_select "a[href=?] .dashboard-overview-value", path, text: value
      end
    end

    visible_post.update!(is_published: 0)
    get slug_admin_dashboard_path(slug: slug)
    assert_select ".dashboard-overview a[href=?] .dashboard-overview-value", slug_admin_posts_path(slug: slug), text: "보이는 글 없음"
  end

  test "최근 문의에서 문의함의 해당 문의로 이동할 수 있다" do
    member = create_overview_member
    inquiry = member.member_inquiries.create!(sender_name: "방문자", sender_email: "visitor@example.com",
      message: "상담을 요청합니다", is_read: 0)

    get slug_admin_dashboard_path(slug: member.slug)

    assert_response :ok
    assert_select "section[aria-labelledby='recent-inquiries-title']" do
      assert_select "span", text: "새 문의 1건"
      assert_select "a[href$='#inquiry-#{inquiry.id}'] span", text: "새 문의"
    end
  end

  test "방문이 없으면 방문 기간과 주소 공유 방법을 보여 준다" do
    member = create_overview_member

    get slug_admin_dashboard_path(slug: member.slug)

    assert_response :ok
    [
      "아직 방문이 없어요. 내 페이지 주소를 고객에게 보내 보세요.",
      "최근 14일 방문 0회",
      "주소 복사",
      "최근 7일 · 내 페이지가 열린 횟수"
    ].each { |phrase| assert_includes response.body, phrase }
    assert_select "a[href=?]", slug_admin_brand_path(slug: member.slug), text: "주별 흐름은 '내 브랜드'에서 보기 →"
    ["14일 방문 추이", "링크 복사", "명이 방문했어요"].each { |phrase| assert_not_includes response.body, phrase }
    assert_not_includes Rails.root.join("app/views/member_admin/dashboard/show.html.erb").read, "impd-font-mono"
  end

  test "오늘 익명 방문이 있으면 페이지가 열린 횟수를 보여 준다" do
    member = create_overview_member
    AnalyticsEvent.create!(event_name: "page_view", event_category: "page", tenant_id: 1,
      user_type: "anonymous", page_path: "/#{member.slug}")

    get slug_admin_dashboard_path(slug: member.slug)

    assert_response :ok
    assert_select "p", text: /오늘 내 페이지 방문 1회 · 최근 7일 1회/
  end

  test "방문이 20회 이상이면 날짜별 막대와 하루 평균을 보여 준다" do
    member = create_overview_member
    21.times do
      AnalyticsEvent.create!(event_name: "page_view", event_category: "page", tenant_id: 1,
        user_type: "anonymous", page_path: "/#{member.slug}", created_at: 1.day.ago)
    end

    get slug_admin_dashboard_path(slug: member.slug)

    assert_response :ok
    assert_select "p", text: /오늘은 아직 방문이 없어요\. 최근 7일 동안은 21회 열렸어요\./
    assert_select "span", text: "최근 14일 방문 21회"
    assert_select ".dashboard-chart .dashboard-chart-date", text: %r{\A\d+/\d+\z}, count: 14
    assert_select "p", text: "오늘 0회 · 하루 평균 1.5회"
    assert_select "a[href=?]", slug_admin_brand_path(slug: member.slug), text: "주별 흐름은 '내 브랜드'에서 보기 →"
  end

  private

  def create_overview_member
    slug = "dashboard-#{SecureRandom.hex(4)}"
    Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug, status: "approved",
      business_type: "individual", password: "password1234", password_confirmation: "password1234").tap do |member|
      post "/auth/login", params: { email: member.email, password: "password1234" }
    end
  end
end
