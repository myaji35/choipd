require "test_helper"

class MemberAdminUnsavedGuardTest < ActionDispatch::IntegrationTest
  GUARDED_FORM = 'form[data-controller~="unsaved-guard"]'

  setup do
    slug = "unsaved-guard-#{SecureRandom.hex(4)}"
    @member = Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug, status: "approved",
      business_type: "individual", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    @pages = {
      slug_admin_services_path(slug: slug) => "new-service",
      slug_admin_faqs_path(slug: slug) => "new-faq",
      slug_admin_posts_path(slug: slug) => "new-post",
      slug_admin_bookings_path(slug: slug) => "new-booking"
    }
  end

  test "정보 확인에서는 내 정보 양식에만 저장 전 이탈 확인을 붙인다" do
    get slug_admin_editor_path(slug: @member.slug, step: 2)

    assert_response :ok
    assert_select GUARDED_FORM, count: 1
    assert_select "#{GUARDED_FORM}[action$='/editor/info'][data-turbo=false]", count: 1
    assert_select "#{GUARDED_FORM} [aria-invalid=true]", count: 0
    assert_includes response.body, "저장을 눌러야 내 페이지에 반영돼요."
  end

  test "정보 저장 실패 후 보호 양식에 오류 필드가 남는다" do
    patch slug_admin_editor_update_info_path(slug: @member.slug), params: { member: { email: "abc" } }

    assert_response :unprocessable_entity
    assert_select "#{GUARDED_FORM} input#member_email[value=abc][aria-invalid=true]"
  end

  test "목록 양식 저장 실패 후 해당 양식에만 오류와 입력값이 남는다" do
    cases = [
      [ :service, @member.member_services.create!(title: "상담"), { title: "", price: "무료" }, :price ],
      [ :faq, @member.member_faqs.create!(question: "질문", answer: "답변"), { answer: "", question: "새 질문" }, :question ],
      [ :post, @member.member_posts.create!(title: "소식", content: "본문"), { content: "", title: "새 소식" }, :title ],
      [ :booking, @member.member_bookings.create!(external_url: "https://example.com"), { external_url: "주소 없음", booking_type: "새 예약" }, :booking_type ]
    ]
    cases.each do |type, record, attributes, retained_field|
      collection_path = public_send("slug_admin_#{type.to_s.pluralize}_path", slug: @member.slug)
      record_path = public_send("slug_admin_#{type}_path", slug: @member.slug, id: record)
      model_key = "member_#{type}"

      post collection_path, params: { model_key => attributes }
      assert_response :unprocessable_entity
      assert_select "#{GUARDED_FORM} [data-unsaved-guard-error]", count: 1
      assert_select "section[id^='new-'] #{GUARDED_FORM}" do
        assert_select "[data-unsaved-guard-error] li"
        assert_select "input[name=?][value=?]", "#{model_key}[#{retained_field}]", attributes.fetch(retained_field)
      end

      patch record_path, params: { model_key => attributes }
      assert_response :unprocessable_entity
      assert_select "#{GUARDED_FORM} [data-unsaved-guard-error]", count: 1
      assert_select "article details[open] #{GUARDED_FORM}" do
        assert_select "[data-unsaved-guard-error] li"
        assert_select "input[name=?][value=?]", "#{model_key}[#{retained_field}]", attributes.fetch(retained_field)
      end
    end
  end

  test "빈 목록의 새 양식을 보호한다" do
    @pages.each do |path, anchor|
      get path

      assert_response :ok
      assert_select "section##{anchor} #{GUARDED_FORM}", count: 1
    end
  end

  test "항목이 있으면 새 양식과 수정 양식에만 보호를 붙인다" do
    @member.member_services.create!(title: "보장 분석 상담")
    @member.member_faqs.create!(question: "상담은 어떻게 하나요?", answer: "전화로 문의해 주세요.")
    @member.member_posts.create!(title: "상담 안내", content: "이번 주 무료 상담")
    @member.member_bookings.create!(external_url: "https://example.com/reservations")

    @pages.each do |path, anchor|
      get path

      assert_response :ok
      assert_select GUARDED_FORM, count: 2
      assert_select "section##{anchor} #{GUARDED_FORM}", count: 1
      assert_select "article details #{GUARDED_FORM}", count: 1
      assert_select "#{GUARDED_FORM} input[name='_method'][value='delete']", count: 0
    end
  end

  test "페이지 이동과 브라우저 이탈을 감지한다" do
    source = File.read(Rails.root.join("app/javascript/controllers/unsaved_guard_controller.js"))
    [ "beforeunload", "turbo:before-visit", "아직 저장하지 않은 내용이 있어요." ].each do |phrase|
      assert_includes source, phrase
    end
  end
end
