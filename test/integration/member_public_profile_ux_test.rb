require "test_helper"

class MemberPublicProfileUxTest < ActionDispatch::IntegrationTest
  setup do
    token = SecureRandom.hex(5)
    @member = Member.create!(name: "테스트 회원", email: "#{token}@example.com", slug: "member-#{token}", status: "approved", profession: "insurance_agent")
  end

  test "both layouts omit empty photos and services and show insurance disclosure" do
    [ "editorial", "grid" ].each do |layout|
      @member.update!(layout_preset: layout)
      get public_profile_path(slug: @member.slug)
      assert_response :success
      assert_not_includes response.body, "지금 가입하면 첫 페이지 제작 무료"
      assert_no_match(/현장 사진/, response.body)
      assert_select "#classes", count: 0
      assert_select ".impd-bento .impd-label", text: "서비스", count: 0
      assert_includes response.body, "모집인 등록번호는 상담 시 안내해 드려요."
      assert_includes response.body, "보험설계사(모집인)의 안내입니다."
    end
  end

  test "이미 보여 준 내용을 다시 늘어놓는 칸은 그리지 않는다" do
    @member.update!(bio: "고객의 상황을 먼저 듣고 필요한 보험을 알기 쉽게 설명하며 함께 선택할 수 있도록 도와드립니다.")
    @member.member_services.create!(title: "보험 상담", is_active: 1)

    get public_profile_path(slug: @member.slug)

    assert_not_includes response.body, "이렇게 도와드립니다"
    assert_not_includes response.body, "자동 구성"
    assert_select "#classes"
    assert_select "#contact form"
  end

  test "자료가 하나도 없는 방문자 화면에도 예시 칸은 없다" do
    get public_profile_path(slug: @member.slug)

    assert_response :success
    assert_not_includes response.body, "이렇게 도와드립니다"
  end

  test "칸 이름이 관리 화면과 같다" do
    @member.member_services.create!(title: "보험 상담", is_active: 1)
    @member.member_posts.create!(title: "상담 소식", content: "상담 일정을 안내해요.", is_published: 1)
    @member.member_portfolio_items.create!(title: "상담 사례", media_url: "https://example.com/photo.jpg")

    get public_profile_path(slug: @member.slug)

    assert_select "#classes .impd-section-header .impd-display", text: "서비스"
    assert_select "#posts .impd-section-header .impd-display", text: "소식"
    assert_select "#gallery .impd-section-header .impd-display", text: "사진·사례"
    assert_select "#gallery .impd-photo-grid figure figcaption", text: /작업 사례/
    [ "갤러리", "서비스 / 수업", "활동 기록", "WORK" ].each do |phrase|
      assert_not_includes response.body, phrase
    end
  end

  test "inquiry requires consent and accepts a phone contact" do
    attributes = { sender_name: "방문자", sender_email: "010-1234-5678", message: "상담을 요청합니다" }
    assert_no_difference "MemberInquiry.count" do
      post member_inquiries_path(slug: @member.slug), params: { member_inquiry: attributes }
    end
    follow_redirect!
    assert_includes response.body, "개인정보 전달에 동의해 주세요."
    assert_difference "MemberInquiry.count", 1 do
      post member_inquiries_path(slug: @member.slug), params: { member_inquiry: attributes.merge(consent: "1") }
    end
    follow_redirect!
    assert_includes response.body, "보냈어요. 보통 24시간 안에 답장이 와요."
  end

  test "긴 서비스 이름 위에 신청 상태를 표시하고 가격에는 본문 글꼴을 쓴다" do
    title = "보험설계사 AI 영업 도구 도입 안내"
    @member.member_services.create!(title: title, price_label: "무료", is_active: 1)

    get public_profile_path(slug: @member.slug)

    assert_response :ok
    assert_select "#classes span.impd-label-muted + h3", text: title
    assert_select "#classes span.impd-label-muted", text: "신청 가능"
    assert_select "#classes p[style*='var(--impd-font-sans)']", text: "무료"
    assert_not_includes css_select("#classes").to_s, "position: absolute"
    assert_not_includes css_select("#classes").to_s, "impd-font-mono"
  end

  test "서비스 카드에 신청 주소가 있으면 회원이 적은 버튼으로 연결한다" do
    @member.member_services.create!(title: "상담", is_active: 1, cta_label: "카톡으로 신청", cta_url: "https://open.kakao.com/o/abc")

    get public_profile_path(slug: @member.slug)

    assert_select "#classes a.public-service-action[href='https://open.kakao.com/o/abc'][target='_blank'][rel='noopener']", text: /카톡으로 신청/
  end

  test "신청 주소가 없으면 문의 양식으로 연결한다" do
    @member.member_services.create!(title: "보장 분석 상담", is_active: 1)

    get public_profile_path(slug: @member.slug)

    assert_select "#classes a.public-service-action[href='#contact'][data-inquiry-service='보장 분석 상담']", text: "이 서비스 문의하기"
  end

  test "안전하지 않은 주소는 버튼 주소로 쓰지 않는다" do
    @member.member_services.create!(title: "상담", is_active: 1, cta_url: "javascript:alert(1)")

    get public_profile_path(slug: @member.slug)

    assert_not_includes response.body, "javascript:alert"
    assert_select "#classes a.public-service-action[href='#contact'][data-inquiry-service='상담']"
  end

  test "카드 모음형에서도 서비스 문의 버튼을 표시한다" do
    @member.update!(layout_preset: "grid")
    @member.member_services.create!(title: "상담", is_active: 1)

    get public_profile_path(slug: @member.slug)

    assert_select ".impd-bento article a.public-service-action[href='#contact']"
  end

  test "자기소개를 자르지 않고 끝까지 보여 준다" do
    bio = ("안녕하세요. " * 20) + "\n끝까지 보입니다"
    @member.update!(bio: bio)

    get public_profile_path(slug: @member.slug)

    assert_select ".public-hero .public-bio", text: /끝까지 보입니다/ do |paragraphs|
      assert_equal bio, paragraphs.first.text
      assert_no_match(/\.\.\.|…/, paragraphs.first.text)
    end
  end

  test "문의 양식은 좁은 폭과 큰 동의 칸을 쓴다" do
    get public_profile_path(slug: @member.slug)

    assert_select "#contact form.public-form label.public-consent input[type=checkbox][required]"
    assert_select "#contact .public-consent-link a[href='/privacy']", text: "개인정보처리방침 보기"
    assert_includes response.body, "max-width: 640px"
    assert_select "#contact textarea#member_inquiry_message[placeholder]"
    assert_select "#contact input#member_inquiry_sender_name"
  end
end
