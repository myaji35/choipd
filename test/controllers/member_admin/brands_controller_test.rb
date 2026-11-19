require "test_helper"

class MemberAdmin::BrandsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(name: "브랜드 회원", email: "brand-#{SecureRandom.hex(4)}@example.com", slug: "brand-#{SecureRandom.hex(4)}", status: "approved", business_type: "individual", profession: "custom", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "shows an empty state without brands" do
    get slug_admin_brand_path(slug: @member.slug)
    assert_response :success
    assert_includes response.body, "아직 등록된 브랜드가 없어요"
  end

  test "shows only the member's brands" do
    Brand.create!(name: "내 브랜드", member_id: @member.id, business_type: "보험", region: "성남")
    Brand.create!(name: "다른 브랜드")
    get slug_admin_brand_path(slug: @member.slug)
    assert_response :success
    assert_includes response.body, "내 브랜드"
    assert_includes response.body, "성남"
    assert_not_includes response.body, "다른 브랜드"
  end
end
