require "test_helper"

class MemberAdmin::SnsPublishesControllerTest < ActionDispatch::IntegrationTest
  test "does not publish to Facebook when the brand channel lacks consent" do
    member = Member.create!(name: "게시 회원", email: "facebook-publisher@example.com", slug: "facebook-publisher",
      status: "approved", password: "password1234", password_confirmation: "password1234")
    account = member.sns_accounts.create!(platform: "facebook", account_name: "게시 페이지", external_id: "123", is_active: true)
    brand = Brand.create!(name: "게시 브랜드", member_id: member.id)
    brand.brand_channels.create!(platform: "facebook_page", sns_account: account)
    post "/auth/login", params: { email: member.email, password: "password1234" }

    facebook_oauth = Class.new
    facebook_oauth.define_singleton_method(:publish_to_page) { |**| flunk "Facebook publish was called without consent" }
    stub_const(Object, :FacebookOauth, facebook_oauth) do
      post slug_admin_publish_facebook_path(slug: member.slug), params: { message: "게시 내용" }
    end

    assert_redirected_to slug_admin_sns_accounts_path(slug: member.slug)
    assert_equal "브랜드 채널의 운영 위탁 동의가 필요합니다.", flash[:alert]
  end
end
