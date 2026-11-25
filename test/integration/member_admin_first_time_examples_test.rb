require "test_helper"

class MemberAdminFirstTimeExamplesTest < ActionDispatch::IntegrationTest
  setup do
    slug = "first-time-examples-#{SecureRandom.hex(4)}"
    @member = Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug,
      status: "approved", business_type: "individual", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "새 질문 양식에서 아직 저장하지 않은 예시만 보여 준다" do
    path = slug_admin_faqs_path(slug: @member.slug)
    example = "상담은 어떻게 진행되나요?"
    chips = "#new-faq .impd-example-chips button[type=button]"
    get path

    assert_response :ok
    assert_select '#new-faq form[data-controller~="example-fill"]'
    assert_select chips, count: 5
    assert_select chips, text: example

    post path, params: { member_faq: { question: example, answer: "전화로 먼저 이야기해요." } }
    assert_redirected_to path
    follow_redirect!

    assert_select chips, count: 4
    assert_select chips, text: example, count: 0
    assert_select "article form .impd-example-chips", count: 0

    css_select(chips).map(&:text).each do |question|
      @member.member_faqs.create!(question: question.strip, answer: "전화로 먼저 이야기해요.")
    end
    get path
    assert_select "#new-faq .impd-example-chips", count: 0
    assert_not_includes response.body, "무엇을 적을지 모르겠다면"
  end

  test "예약 주소부터 보여 주고 이름 예시는 새 양식에만 있다" do
    get slug_admin_bookings_path(slug: @member.slug)

    assert_response :ok
    assert_equal [ "예약 주소 (필수)", "버튼 옆에 보일 이름 (선택)", "설명 (선택)" ],
      css_select("#new-booking form label").map(&:text)
    assert_select 'input[name="member_booking[external_url]"][type=text][inputmode=url][required]', count: 1
    assert_select "input[type=url]", count: 0
    assert_select "#new-booking .impd-example-chips button[type=button]", count: 3
    assert_includes response.body, "없으면 비워 둬도 괜찮아요"
  end

  test "예약 주소에 스킴을 보완하고 기존 http 주소는 유지한다" do
    path = slug_admin_bookings_path(slug: @member.slug)
    {
      " booking.naver.com/abc " => "https://booking.naver.com/abc",
      "http://a.example/x" => "http://a.example/x"
    }.each do |input, expected|
      assert_difference -> { @member.member_bookings.count }, 1 do
        post path, params: { member_booking: { external_url: input } }
        assert_redirected_to path
      end
      assert_equal expected, @member.member_bookings.recent.first.external_url
      follow_redirect!
      assert_select "article a[href=?]", expected
      assert_select "article form .impd-example-chips", count: 0
    end
  end

  test "예약 주소 오류를 쉬운 말로 안내한다" do
    path = slug_admin_bookings_path(slug: @member.slug)
    {
      "주소 없음" => "예약 주소를 다시 확인해 주세요. 띄어쓰기 없이 주소만 적어 주세요.",
      "ftp://a.example/x" => "예약 주소를 다시 확인해 주세요. 띄어쓰기 없이 주소만 적어 주세요.",
      " " => "예약 주소를 적어 주세요."
    }.each do |input, message|
      post path, params: { member_booking: { external_url: input } }

      assert_response :unprocessable_entity
      assert_select "#new-booking [role=alert] li", text: message
      assert_not_includes response.body, "External"
    end
  end

  test "서비스 신청 주소는 만들거나 수정할 때 보완하고 비워 둘 수 있다" do
    path = slug_admin_services_path(slug: @member.slug)
    post path, params: { member_service: { title: "상담", cta_url: "open.kakao.com/o/abc" } }

    assert_redirected_to path
    service = @member.member_services.sole
    assert_equal "https://open.kakao.com/o/abc", service.cta_url
    follow_redirect!
    assert_select 'input[name="member_service[cta_url]"][type=text][inputmode=url]', count: 2
    assert_select "input[type=url]", count: 0

    edit_path = slug_admin_service_path(slug: @member.slug, id: service)
    patch edit_path, params: { member_service: { cta_url: "open.kakao.com/o/xyz" } }
    assert_redirected_to path
    assert_equal "https://open.kakao.com/o/xyz", service.reload.cta_url

    patch edit_path, params: { member_service: { cta_url: "" } }
    assert_redirected_to path
    assert_equal "", service.reload.cta_url
  end
end
