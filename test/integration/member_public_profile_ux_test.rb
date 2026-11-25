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
      assert_no_match(/서비스 \/ 수업/, response.body)
      assert_includes response.body, "모집인 등록번호는 상담 시 안내해 드려요."
      assert_includes response.body, "보험설계사(모집인)의 안내입니다."
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
end
