require "test_helper"

class MemberAdminPageWidthTest < ActionDispatch::IntegrationTest
  setup do
    @slug = "page-width-#{SecureRandom.hex(4)}"
    member = Member.create!(name: "테스트 회원", email: "#{@slug}@example.com", slug: @slug, status: "approved",
      business_type: "individual", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: member.email, password: "password1234" }
  end

  test "대시보드와 페이지 만들기는 같은 본문 폭을 쓴다" do
    paths = [ slug_admin_dashboard_path(slug: @slug) ] +
      (1..4).map { |step| slug_admin_editor_path(slug: @slug, step: step) }
    paths.each do |path|
      get path

      assert_response :ok
      assert_includes response.body, "--admin-page-max-width, 1120px"
      assert_not_includes response.body, "1400px"
      assert_not_includes response.body, "--admin-page-max-width: 1200px"
    end
  end

  test "목록과 홍보 화면은 같은 본문 폭과 여백을 쓴다" do
    %w[services faqs posts inquiries reviews bookings brand channels brand_consents].each do |page|
      get public_send("slug_admin_#{page}_path", slug: @slug)

      assert_response :ok
      wrapper = page == "inquiries" ? ".inquiries-wrap" : ".impd-wrap"
      assert_select "#{wrapper}[style='max-width: 1120px; margin: 0 auto; padding: 40px;']", count: 1
      assert_not_includes response.body, "1040px" if page == "inquiries"
      if page == "brand_consents"
        assert_not_includes response.body, "900px"
        assert_select "header p.impd-label-muted", text: "홍보 › 노출·광고 동의"
      end
    end
  end
end
