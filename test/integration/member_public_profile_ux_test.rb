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

  test "문의를 보내면 문의 칸으로 돌아와 보냈다는 안내만 보인다" do
    @member.update!(layout_preset: "editorial")
    assert_difference "MemberInquiry.count", 1 do
      post member_inquiries_path(slug: @member.slug), params: { member_inquiry: inquiry_attributes }
    end

    assert_inquiry_confirmation
    get public_profile_path(slug: @member.slug, anchor: "contact")
    assert_select "#contact form"
    assert_select "#inquiry-sent", count: 0
  end

  test "카드 모음형에서도 보냈다는 안내만 보인다" do
    @member.update!(layout_preset: "grid")
    post member_inquiries_path(slug: @member.slug), params: { member_inquiry: inquiry_attributes }

    assert_inquiry_confirmation
  end

  test "동의가 없으면 문의 칸으로 돌아와 이유를 알려 준다" do
    assert_no_difference "MemberInquiry.count" do
      post member_inquiries_path(slug: @member.slug), params: { member_inquiry: inquiry_attributes.except(:consent) }
    end

    assert_redirected_to public_profile_path(slug: @member.slug, anchor: "contact")
    follow_redirect!
    assert_select "#contact [role=alert]", text: "개인정보 전달에 동의해 주세요."
  end

  test "honeypot 이 채워지면 저장하지 않고 같은 안내를 보여 준다" do
    assert_no_difference "MemberInquiry.count" do
      post member_inquiries_path(slug: @member.slug), params: { website: "x", member_inquiry: inquiry_attributes }
    end

    assert_inquiry_confirmation
  end

  test "저장할 수 없는 문의는 문의 칸에서 다시 입력할 수 있다" do
    assert_no_difference "MemberInquiry.count" do
      post member_inquiries_path(slug: @member.slug), params: { member_inquiry: inquiry_attributes.merge(message: "") }
    end

    assert_redirected_to public_profile_path(slug: @member.slug, anchor: "contact")
    follow_redirect!
    assert_select "#contact [role=alert]"
    assert_select "#contact form"
  end

  test "요약 명함에서 바로 문의 칸으로 갈 수 있다" do
    get public_profile_card_path(slug: @member.slug)

    assert_response :ok
    assert_select ".cs-left a.cs-inquiry[href='/#{@member.slug}#contact']", text: "상담·문의하기"
    assert_select "a.cs-full[href='/#{@member.slug}']", text: /전체 프로필 보기/
    assert_operator response.body.index('class="cs-inquiry"'), :<, response.body.index('class="cs-full"')
  end

  test "길게 읽는 형 첫머리에 하는 일을 보여 준다" do
    @member.update!(layout_preset: "editorial")
    @member.member_services.create!(title: "보장 분석 상담", is_active: 1, sort_order: 0)
    @member.member_services.create!(title: "보험금 청구 도움", is_active: 1, sort_order: 1)
    @member.member_portfolio_items.create!(title: "상담 사례", media_url: "https://example.com/photo.jpg")

    get public_profile_path(slug: @member.slug)

    assert_select ".public-hero p.public-offer", text: /하는 일\s*보장 분석 상담 · 보험금 청구 도움/
    assert_select ".public-hero .public-actions a[href='#classes']", text: "서비스 보기"
    assert_operator response.body.index('id="classes"'), :<, response.body.index('id="contact"')
    assert_operator response.body.index('id="classes"'), :<, response.body.index('id="gallery"')
  end

  test "서비스가 넷 이상이면 셋만 적고 나머지는 개수로 표시한다" do
    @member.update!(layout_preset: "editorial")
    (1..5).each do |order|
      @member.member_services.create!(title: "서비스 #{order}", is_active: 1, sort_order: order)
    end

    get public_profile_path(slug: @member.slug)

    assert_select ".public-offer", text: "하는 일 서비스 1 · 서비스 2 · 서비스 3 외 2개"
  end

  test "서비스가 없으면 하는 일 줄과 서비스 보기 버튼이 없다" do
    @member.update!(layout_preset: "editorial")
    get public_profile_path(slug: @member.slug)

    assert_select ".public-offer", count: 0
    assert_select ".public-actions a[href='#classes']", count: 0
  end

  test "카드 모음형 첫머리에는 하는 일 줄을 겹쳐 넣지 않는다" do
    @member.update!(layout_preset: "grid")
    @member.member_services.create!(title: "상담", is_active: 1)

    get public_profile_path(slug: @member.slug)

    assert_select ".public-offer", count: 0
    assert_select ".impd-bento article a.public-service-action"
  end

  test "웹사이트 주소로 올린 사례는 그림 대신 누를 수 있는 링크 타일로 보여 준다" do
    @member.member_portfolio_items.create!(title: "동네 가게 홍보", media_url: "https://example.com", media_type: "link")

    get public_profile_path(slug: @member.slug)

    assert_select "#gallery figure a.impd-case-link[href='https://example.com'][target=_blank][rel=noopener]"
    assert_select "#gallery img[src='https://example.com']", count: 0
    assert_select "#gallery figure figcaption .impd-case-go", text: /example\.com 보러 가기/
    assert_select "#gallery .impd-section-header .impd-label-muted", text: "1개"
  end

  test "media_type 이 비어 있어도 그림 주소가 아니면 링크 타일이다" do
    @member.member_portfolio_items.create!(title: "동네 가게 홍보", media_url: "https://example.com/work", media_type: nil)

    get public_profile_path(slug: @member.slug)

    assert_select "#gallery a.impd-case-link[href='https://example.com/work']"
    assert_select "#gallery img", count: 0
  end

  test "그림 주소로 올린 사례는 지금처럼 그림으로 보여 준다" do
    @member.member_portfolio_items.create!(title: "동네 가게 홍보", media_url: "https://example.com/photo.jpg")

    get public_profile_path(slug: @member.slug)

    assert_select "#gallery img[src='https://example.com/photo.jpg']"
    assert_select "#gallery a.impd-case-link", count: 0
    assert_select "#gallery .impd-section-header .impd-label-muted", text: "사진 1개"
  end

  test "안전하지 않은 주소는 사례 링크로 쓰지 않는다" do
    @member.member_portfolio_items.create!(title: "동네 가게 홍보", media_url: "javascript:alert(1)", media_type: "link")

    get public_profile_path(slug: @member.slug)

    assert_select "#gallery a", count: 0
    assert_select "#gallery img", count: 0
    assert_select "#gallery .impd-case-go", count: 0
    assert_select "#gallery .impd-photo-title", text: "동네 가게 홍보"
  end

  test "카드 모음형에도 링크 사례를 보여 준다" do
    @member.update!(layout_preset: "grid")

    get public_profile_path(slug: @member.slug)
    assert_select ".impd-bento-case", count: 0

    @member.member_portfolio_items.create!(title: "동네 가게 홍보", media_url: "https://example.com", media_type: "link")
    @member.member_portfolio_items.create!(title: "홍보 사진", media_url: "https://example.com/photo.jpg")

    get public_profile_path(slug: @member.slug)

    assert_select ".impd-bento a.impd-bento-case", count: 1
    assert_select ".impd-bento a.impd-bento-case[href='https://example.com'][target=_blank][rel=noopener]", text: /동네 가게 홍보.*보러 가기/m
  end

  test "문의 칸에 오면 하단 띠를 치우는 장치가 있다" do
    [ "editorial", "grid" ].each do |layout|
      @member.update!(layout_preset: layout)
      get public_profile_path(slug: @member.slug)

      assert_select "nav.public-sticky a.primary[href='#contact']", text: "문의"
      assert_includes response.body, ".public-sticky.is-away { display: none; }"
      assert_includes response.body, "classList.toggle('is-away'"
    end
  end

  test "방문 고객에게는 imPD 플랫폼 메뉴를 보여 주지 않는다" do
    [ "editorial", "grid" ].each do |layout|
      @member.update!(layout_preset: layout)
      get public_profile_path(slug: @member.slug)
      assert_visitor_topnav
    end

    get public_profile_card_path(slug: @member.slug)
    assert_visitor_topnav
  end

  test "다른 화면의 상단 메뉴는 그대로다" do
    [ root_path, explore_path ].each do |path|
      get path

      assert_select "nav.impd-topnav-links a", text: "둘러보기"
      assert_select "#impd-mobile-menu"
    end
  end

  test "요약 명함에 하는 일을 보여 준다" do
    @member.member_services.create!(title: "보장 분석 상담", is_active: 1, sort_order: 0)
    @member.member_services.create!(title: "보험금 청구 도움", is_active: 1, sort_order: 1)

    get public_profile_card_path(slug: @member.slug)

    assert_select ".cs-left p.cs-offer", text: /하는 일\s*보장 분석 상담 · 보험금 청구 도움/
    assert_operator response.body.index('class="cs-offer"'), :<, response.body.index('class="cs-inquiry"')
  end

  test "요약 명함도 서비스가 넷 이상이면 셋만 적는다" do
    (1..5).each do |order|
      @member.member_services.create!(title: "서비스 #{order}", is_active: 1, sort_order: order)
    end

    get public_profile_card_path(slug: @member.slug)

    assert_select ".cs-offer", text: "하는 일 서비스 1 · 서비스 2 · 서비스 3 외 2개"
  end

  test "서비스가 없거나 마감뿐이면 요약 명함에 하는 일 줄이 없다" do
    get public_profile_card_path(slug: @member.slug)
    assert_select ".cs-offer", count: 0

    @member.member_services.create!(title: "마감된 상담", is_active: 0)

    get public_profile_card_path(slug: @member.slug)
    assert_select ".cs-offer", count: 0
  end

  test "카드 모음형에도 경력·후기·자주 묻는 질문을 보여 준다" do
    @member.update!(layout_preset: "grid", profession: "creator", career_note: "동네 가게 홍보 10년")
    @member.member_faqs.create!(question: "상담은 어떻게 하나요?", answer: "전화로 먼저 이야기해요.", is_published: 1)
    @member.member_reviews.create!(reviewer_name: "김고객", rating: 5, status: "triaged", content: "설명이 쉬웠어요.")

    get public_profile_path(slug: @member.slug)

    assert_select ".impd-bento .impd-bento-career p", text: "동네 가게 홍보 10년"
    assert_select ".impd-bento .impd-bento-review blockquote", text: /설명이 쉬웠어요\./
    assert_select ".impd-bento .impd-bento-review figcaption", text: /김고객/
    assert_select ".impd-bento .impd-bento-faq details summary", text: "상담은 어떻게 하나요?"
    assert_select ".impd-bento .impd-bento-faq details[open]", count: 0
    assert_operator response.body.index('class="impd-bento-tile impd-bento-career"'), :<, response.body.index('id="contact"')
  end

  test "자료가 없으면 카드 모음형에 빈 타일을 만들지 않는다" do
    @member.update!(layout_preset: "grid", profession: "creator")

    get public_profile_path(slug: @member.slug)

    assert_select ".impd-bento-career, .impd-bento-review, .impd-bento-faq", count: 0
  end

  test "공개하지 않은 후기·질문은 카드 모음형에도 나오지 않는다" do
    @member.update!(layout_preset: "grid")
    @member.member_faqs.create!(question: "비공개 질문", answer: "비공개 답변", is_published: 0)
    @member.member_reviews.create!(reviewer_name: "김고객", rating: 5, status: "new", content: "비공개 후기")

    get public_profile_path(slug: @member.slug)

    assert_select ".impd-bento-review", count: 0
    assert_select ".impd-bento-faq", count: 0
  end

  test "보험설계사는 경력을 상담 안내에만 보여 준다" do
    @member.update!(layout_preset: "grid", career_note: "보험 상담 10년")

    get public_profile_path(slug: @member.slug)

    assert_select ".impd-bento-career", count: 0
    assert_select ".public-member-inner p", text: /자격·경력:.*보험 상담 10년/m
  end

  test "카드 모음형도 서비스를 여섯 개까지 보여 준다" do
    @member.update!(layout_preset: "grid")
    (1..5).each do |order|
      @member.member_services.create!(title: "서비스 #{order}", is_active: 1, sort_order: order)
    end

    get public_profile_path(slug: @member.slug)
    assert_select ".impd-bento article a.public-service-action", count: 5

    (6..7).each do |order|
      @member.member_services.create!(title: "서비스 #{order}", is_active: 1, sort_order: order)
    end

    get public_profile_path(slug: @member.slug)
    assert_select ".impd-bento article a.public-service-action", count: 6
  end

  test "일상 장면 칸에 회원이 쓰지 않은 소개 문장을 넣지 않는다" do
    @member.update!(layout_preset: "editorial")
    @member.member_photos.create!(category: "daily", image: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png"))

    get public_profile_path(slug: @member.slug)

    assert_select "#moments"
    assert_not_includes response.body, "수강생의 환한 표정"
    assert_not_includes response.body, "한 줄의 카피보다"
  end

  private

  def assert_visitor_topnav
    assert_select ".impd-topnav a[href='/']", text: "imPD"
    assert_select "nav.impd-topnav-links", count: 0
    assert_select "#impd-mobile-menu", count: 0
    assert_select ".impd-nav-toggle", count: 0
    assert_select ".impd-topnav a", text: "로그인", count: 0
    assert_select ".impd-topnav a", text: "회원가입", count: 0
  end

  def inquiry_attributes
    { sender_name: "방문자", sender_email: "010-1234-5678", message: "상담을 요청합니다", consent: "1" }
  end

  def assert_inquiry_confirmation
    assert_response :see_other
    assert_redirected_to public_profile_path(slug: @member.slug, anchor: "contact")
    follow_redirect!

    assert_select "#contact #inquiry-sent[role=status]", text: /보냈어요\. 보통 24시간 안에 답장이 와요\./
    assert_select "#contact form", count: 0
    assert_select ".shared-flash", count: 0
    assert_select "#inquiry-sent a[href$='#contact']", text: "다른 문의 더 보내기"
  end
end
