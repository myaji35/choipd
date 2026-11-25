require "test_helper"

class MemberAdmin::BrandsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @old_active_min = ENV["BRAND_OPS_ACTIVE_MIN"]
    @old_communication_min = ENV["BRAND_OPS_COMMUNICATION_MIN"]
    ENV["BRAND_OPS_ACTIVE_MIN"] = "0"
    ENV["BRAND_OPS_COMMUNICATION_MIN"] = "0"
    @member = Member.create!(name: "브랜드 회원", email: "brand-#{SecureRandom.hex(4)}@example.com", slug: "kang-seung-sig", status: "approved", business_type: "individual", profession: "custom", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  teardown do
    ENV["BRAND_OPS_ACTIVE_MIN"] = @old_active_min
    ENV["BRAND_OPS_COMMUNICATION_MIN"] = @old_communication_min
  end

  test "shows an empty state without brands" do
    get slug_admin_brand_path(slug: @member.slug)
    assert_response :success
    assert_includes response.body, "/kang-seung-sig/brand"
    assert_includes response.body, "고객도 볼 수 있는 내 활동 화면이 따로 있어요."
    assert_not_includes response.body, "/slug/brand"
    assert_includes response.body, "아직 등록된 브랜드가 없어요"
    assert_includes response.body, "브랜드는 운영팀이 등록을 도와드려요"
    assert_select "a.impd-btn-secondary", text: "공개하려면 노출 동의하기"
    assert_select "a[href=?]", slug_admin_channels_path(slug: @member.slug), text: "내 채널 보기"
  end

  test "shows only the member's brands" do
    Brand.create!(name: "내 브랜드", member_id: @member.id, business_type: "보험", region: "성남")
    Brand.create!(name: "다른 브랜드")
    get slug_admin_brand_path(slug: @member.slug)
    assert_response :success
    assert_includes response.body, "내 브랜드"
    assert_includes response.body, "성남"
    assert_not_includes response.body, "다른 브랜드"
    assert_not_includes response.body, "브랜드는 운영팀이 등록을 도와드려요"
  end
  test "shows raw four week counts and changes" do
    travel_to Time.find_zone!("Asia/Seoul").local(2026, 11, 25, 12)
    last_week = 1.week.ago
    4.times { AnalyticsEvent.create!(event_name: "page_view", event_category: "page", page_path: "/#{@member.slug}", created_at: last_week) }
    MemberInquiry.create!(member: @member, sender_name: "방문자", sender_email: "visitor@example.com", message: "문의 내용입니다", created_at: last_week)
    2.times { MemberPost.create!(member: @member, title: "이전 게시", content: "내용", is_published: 1, published_at: 5.weeks.ago) }
    scheduled = SnsScheduledPost.create!(member: @member, message: "내용", platform: "instagram", scheduled_at: last_week)
    2.times { SnsPostHistory.create!(sns_scheduled_post: scheduled, status: "success", created_at: last_week) }
    get slug_admin_brand_path(slug: @member.slug)
    assert_select ".ops-owner-stats section", count: 4
    assert_select ".ops-owner-stats section", text: /방문.*4회.*4회 늘었어요/m
    assert_select ".ops-owner-stats section", text: /문의.*1건.*1건 늘었어요/m
    assert_select ".ops-owner-stats section", text: /올린 소식.*0건.*2건 줄었어요/m
    assert_select ".ops-owner-stats section", text: /SNS에 올린 글.*2건.*2건 늘었어요/m
    assert_includes response.body, "이번 달 소식 0건 · SNS에 올린 글 2건"
  end

  test "내 채널에 올린 블로그 글이 내 브랜드 숫자에도 잡힌다" do
    seoul = Time.find_zone!("Asia/Seoul")
    travel_to seoul.local(2026, 11, 25, 12) do
      brand = @member.brands.create!(name: "개인 브랜드", personal: true)
      channel = brand.brand_channels.create!(platform: "naver_blog", delegation_consent_at: seoul.local(2026, 11, 1))
      [ 8, 16, 22 ].each do |day|
        published_at = seoul.local(2026, 11, day, 12)
        SnsScheduledPost.create!(brand_channel: channel, platform: "naver_blog", title: "블로그 글", message: "블로그 글",
          status: "published", scheduled_at: published_at, published_at: published_at)
      end

      get slug_admin_brand_path(slug: @member.slug)

      assert_response :ok
      assert_select ".ops-owner-stats section", text: /SNS에 올린 글.*3건/m
      assert_includes response.body, "이번 달 소식 0건 · SNS에 올린 글 3건"
    end
  end

  test "끝난 4주만 비교하고 이번 주 방문은 따로 보여 준다" do
    travel_to Time.find_zone!("Asia/Seoul").local(2026, 11, 25, 12) do
      { 0 => 5, 1 => 3, 5 => 1 }.each do |weeks_ago, count|
        count.times do
          AnalyticsEvent.create!(event_name: "page_view", event_category: "page", page_path: "/kang-seung-sig",
            created_at: weeks_ago.weeks.ago, user_agent: "Mozilla/5.0")
        end
      end

      get slug_admin_brand_path(slug: @member.slug)

      assert_response :ok
      assert_select ".ops-owner-stats section:first-child" do
        assert_select "strong", text: "3회"
        assert_select "p", text: "그전 4주보다 2회 늘었어요"
      end
      assert_select ".ops-chart-wrapper + p",
        text: "이번 주(월요일부터 지금까지): 방문 5회 · 문의 0건 · 소식 0건 · SNS에 올린 글 0건"
      assert_includes response.body, "지난 4주(10/26~11/22)"
      assert_includes response.body, "아직 지나고 있는 이번 주는 빼고 셌어요."
      assert_not_includes response.body, "최근 4주 활동과 그전 4주와의 차이예요."
    end
  end

  test "진행 중인 이번 주를 설명하고 현재까지의 숫자를 보여 준다" do
    get slug_admin_brand_path(slug: @member.slug)

    assert_response :ok
    assert_includes response.body, "이번 주는 아직 세는 중이라 그래프에서 빼고 아래에 따로 적었어요."
    assert_select ".ops-chart-wrapper + p",
      text: "이번 주(월요일부터 지금까지): 방문 0회 · 문의 0건 · 소식 0건 · SNS에 올린 글 0건"
    assert_select ".ops-owner-stats .ops-surface-card > p:first-child", text: "올린 소식"
    assert_select ".ops-owner-stats .ops-surface-card > p:first-child", text: "SNS에 올린 글"
  end

  test "그래프의 점과 날짜 눈금은 끝난 주만 보여 준다" do
    seoul = Time.find_zone!("Asia/Seoul")
    travel_to seoul.local(2026, 11, 25, 12) do
      [1.week.ago, 1.week.ago, 1.week.ago, 1.week.ago, Time.current].each do |date|
        AnalyticsEvent.create!(event_name: "page_view", event_category: "page", page_path: "/#{@member.slug}",
          created_at: date, user_agent: "Mozilla/5.0")
      end

      get slug_admin_brand_path(slug: @member.slug)

      assert_response :ok
      completed_count = BrandOps::WeeklyStats.member(@member).size - 1
      monday = Time.current.in_time_zone(seoul).beginning_of_week.strftime("%-m/%-d")
      assert_not_includes response.body, "낮게 보여도 괜찮아요"
      assert_includes response.body, "끝난 주만 이은 흐름이에요"
      assert_select ".ops-weeks span", count: completed_count
      assert_select ".ops-weeks span", text: monday, count: 0
      assert_select ".ops-chart-wrapper polyline", count: 4 do |lines|
        lines.each { |line| assert_equal completed_count, line["points"].split.size }
      end
    end
  end

  test "화면 순서와 쉬운 말" do
    get slug_admin_brand_path(slug: @member.slug)

    assert_response :ok
    headings = assert_select("main h2").map(&:text)
    assert_operator headings.index("내 브랜드 운영 현황"), :<, headings.index("내 정보가 실리는 곳")
    assert_operator headings.index("내 정보가 실리는 곳"), :<, headings.index("내 브랜드 정보")
    assert_select "details summary", text: "이 숫자는 누가 볼 수 있나요?"
    [ "연결 상태", "동의 상태 확인", "콘텐츠·성과" ].each { |phrase| assert_not_includes response.body, phrase }
    assert_select "p.impd-label-muted", text: "홍보 › 내 브랜드"
  end

  test "동의 여부에 따라 상태와 버튼이 바뀐다" do
    get slug_admin_brand_path(slug: @member.slug)

    assert_response :ok
    assert_includes response.body, "아직 맡기지 않았어요"
    assert_select "a.impd-btn-secondary", text: "동의하러 가기", count: 2

    ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true)
    get slug_admin_brand_path(slug: @member.slug)

    assert_response :ok
    assert_includes response.body, "맡기는 중"
    assert_select "a.impd-btn-secondary", text: "동의 내용 보기·바꾸기", count: 1
    assert_select "a.impd-btn-secondary", text: "동의하러 가기", count: 1
  end

  test "정보가 빈 브랜드에는 채우는 방법을 알려 준다" do
    Brand.create!(name: "빈 브랜드", member_id: @member.id)
    Brand.create!(name: "업종이 있는 브랜드", member_id: @member.id, business_type: "보험")

    get slug_admin_brand_path(slug: @member.slug)

    assert_response :ok
    assert_select "article.impd-card h3", text: /빈 브랜드/, count: 0
    assert_select "p[data-empty-brands]", text: /정보가 아직 없는 추가 브랜드 1개: 빈 브랜드\./ do
      assert_select "a[href=?]", new_inquiry_path, text: "문의하기"
    end
    assert_select "article.impd-card h3", text: /업종이 있는 브랜드/ do
      assert_select "span.impd-label-muted", text: "추가 브랜드"
    end
  end

  test "개인 브랜드와 이름이 같은 빈 추가 브랜드는 카드로 표시하지 않는다" do
    @member.brands.create!(name: "같은 이름", personal: true)
    @member.brands.create!(name: "같은 이름")

    get slug_admin_brand_path(slug: @member.slug)

    assert_response :ok
    assert_select "article.impd-card h3", text: /같은 이름/, count: 1 do
      assert_select "span.impd-label", text: "개인(기본)"
    end
    assert_select "p[data-empty-brands]", text: /정보가 아직 없는 추가 브랜드 1개: 같은 이름\./
  end

  test "정보가 비어도 연결 채널이 있는 추가 브랜드는 채널과 함께 보여 준다" do
    @member.brands.create!(name: "개인 브랜드", personal: true)
    brand = @member.brands.create!(name: "채널이 있는 브랜드")
    channel = brand.brand_channels.create!(platform: "naver_blog", account_handle: "my-blog")

    get slug_admin_brand_path(slug: @member.slug)

    assert_response :ok
    assert_select "[data-empty-brands]", count: 0
    assert_select "article.impd-card", text: /채널이 있는 브랜드/ do
      assert_select "h4", text: "브랜드 채널"
      assert_select "li", text: /my-blog/
      assert_select "a[href=?]", edit_slug_admin_brand_brand_channel_path(slug: @member.slug, id: channel.id)
      assert_select "p", text: /업종·지역·소개가 아직 비어 있어요/
    end
  end

  test "개인 브랜드가 비어 있으면 내 페이지 정보를 보여 준다" do
    @member.update!(region: "성남", bio: "소상공인 홍보를 돕습니다. " * 3)
    Brand.create!(name: "개인", member_id: @member.id, personal: true)

    get slug_admin_brand_path(slug: @member.slug)

    assert_response :ok
    assert_select "article.impd-card" do |cards|
      assert_includes cards.first.text, "지역: 성남"
      assert_includes cards.first.text, "소상공인 홍보를 돕습니다."
      assert_includes cards.first.text, "내 페이지에 적은 정보를 그대로 써요."
      assert_not_includes cards.first.text, "직업: custom"
      assert_not_includes cards.first.text, "업종·지역·소개가 아직 비어 있어요"
      assert_select "a[href=?]", slug_admin_editor_path(slug: @member.slug, step: 2), text: "내 정보 고치기"
    end
  end

  test "하나뿐인 브랜드가 비어 있으면 내 페이지 정보를 보여 준다" do
    @member.update!(region: "성남", bio: "소상공인 홍보를 돕습니다. " * 3)
    Brand.create!(name: "하나뿐인 브랜드", member_id: @member.id)

    get slug_admin_brand_path(slug: @member.slug)

    assert_response :ok
    assert_select "article.impd-card", count: 1 do |cards|
      assert_includes cards.first.text, "지역: 성남"
      assert_includes cards.first.text, "소상공인 홍보를 돕습니다."
      assert_includes cards.first.text, "내 페이지에 적은 정보를 그대로 써요."
      assert_select "a[href=?]", slug_admin_editor_path(slug: @member.slug, step: 2), text: "내 정보 고치기"
    end
    assert_not_includes response.body, "운영팀에 알려 주시면"
  end

  test "개인 브랜드도 내 정보도 비어 있으면 적으러 가게 안내한다" do
    @member.update_columns(profession: nil, region: nil, bio: nil)
    Brand.create!(name: "개인", member_id: @member.id, personal: true)

    get slug_admin_brand_path(slug: @member.slug)

    assert_response :ok
    assert_select "article.impd-card" do
      assert_select "p", text: "아직 직업·지역·소개를 적지 않았어요. 적어 두면 운영팀이 홍보할 때 그대로 써요."
      assert_select "a[href=?]", slug_admin_editor_path(slug: @member.slug, step: 2, anchor: "bio"), text: "내 정보 적으러 가기"
    end
  end
end
