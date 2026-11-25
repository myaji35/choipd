require "test_helper"

class MemberAdminFormFieldsTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_member
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    slug = @member.slug
    @pages = {
      services: [ slug_admin_services_path(slug: slug), "new-service", "+ 새 서비스 추가" ],
      faqs: [ slug_admin_faqs_path(slug: slug), "new-faq", "+ 새 질문 추가" ],
      posts: [ slug_admin_posts_path(slug: slug), "new-post", "+ 새 소식 쓰기" ],
      bookings: [ slug_admin_bookings_path(slug: slug), "new-booking", "+ 새 예약 링크 추가" ]
    }
  end

  test "관리 화면의 입력 칸은 공용 스타일을 사용한다" do
    @pages.each_value do |path, target, _label|
      get path

      assert_response :ok
      assert_select "section##{target} input.impd-input", minimum: 1
      %w[service-input faq-input post-input booking-input].each do |old_class|
        assert_not_includes response.body, old_class
      end
    end

    get @pages.fetch(:services).first

    assert_select ".impd-field-row" do
      %w[price price_label].each do |field|
        assert_select "input[name='member_service[#{field}]']", count: 1
      end
    end
  end

  test "질문의 순서는 저장된 질문을 고칠 때만 보인다" do
    path = @pages.fetch(:faqs).first
    order_field = "input[name='member_faq[sort_order]']"
    get path
    assert_select order_field, count: 0

    post path, params: { member_faq: { question: "상담은 어떻게 하나요?", answer: "전화로 문의해 주세요." } }
    assert_redirected_to path
    follow_redirect!

    assert_equal 0, @member.member_faqs.sole.sort_order
    assert_includes response.body, "질문을 저장했어요"
    assert_select order_field, count: 1
    assert_select "article details #{order_field}", count: 1
  end

  test "서비스와 예약 링크를 저장한 뒤 결과를 안내한다" do
    service_path = @pages.fetch(:services).first
    post service_path, params: { member_service: { title: "보장 분석 상담" } }
    assert_redirected_to service_path
    follow_redirect!
    assert_includes response.body, "서비스를 저장했어요"

    booking_path = @pages.fetch(:bookings).first
    post booking_path, params: { member_booking: { external_url: "https://example.com/reservations" } }
    assert_redirected_to booking_path
    follow_redirect!
    assert_includes response.body, "예약 링크를 저장했어요"
  end

  test "목록에 항목이 있으면 머리말에서 새 양식으로 이동할 수 있다" do
    @member.member_services.create!(title: "보장 분석 상담")
    @member.member_faqs.create!(question: "상담은 어떻게 하나요?", answer: "전화로 문의해 주세요.")
    @member.member_posts.create!(title: "상담 안내", content: "이번 주 무료 상담")
    @member.member_bookings.create!(external_url: "https://example.com/reservations")

    @pages.each_value do |path, target, label|
      get path

      assert_response :ok
      assert_select "header a.impd-jump-new[href='##{target}']", text: label
      assert_select "section##{target}", count: 1
    end
  end

  test "목록이 비면 새 양식 바로가기를 숨기고 빈 목록 클래스를 붙인다" do
    @pages.each do |name, (path, target, _label)|
      get path

      assert_response :ok
      assert_select "a.impd-jump-new", count: 0
      assert_select ".#{name}-layout.is-empty > section##{target}", count: 1
    end
  end

  private

  def create_member
    slug = "form-fields-#{SecureRandom.hex(4)}"
    Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug, status: "approved",
      business_type: "individual", password: "password1234", password_confirmation: "password1234")
  end
end
