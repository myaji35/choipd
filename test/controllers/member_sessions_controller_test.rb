require "test_helper"

class MemberSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(name: "회원", email: "member-#{SecureRandom.hex(4)}@example.com",
      slug: "member-#{SecureRandom.hex(4)}", status: "approved", password: "password1234")
  end

  test "OAuth 계정은 빈 비밀번호로 로그인하거나 관리자 화면에 접근할 수 없다" do
    @member.update_columns(password_digest: nil)
    post login_member_post_path(slug: @member.slug), params: { password: "" }
    assert_redirected_to member_login_path
    assert_nil session[:member_id]
    get "/#{@member.slug}/admin/dashboard"
    assert_redirected_to login_member_path(slug: @member.slug)
    assert_nil session[:member_id]
  end

  test "올바른 비밀번호로 로그인한다" do
    post login_member_post_path(slug: @member.slug), params: { password: "password1234" }
    assert_redirected_to "/#{@member.slug}/admin/dashboard"
    assert_equal @member.id, session[:member_id]
  end

  test "잘못된 비밀번호와 알 수 없는 회원은 거부한다" do
    [ @member.slug, "unknown-member" ].each do |slug|
      post login_member_post_path(slug: slug), params: { password: "wrong" }
      assert_redirected_to login_member_path(slug: slug)
      assert_equal "비밀번호를 확인해주세요", flash[:alert]
      assert_nil session[:member_id]
    end
  end

  test "탈퇴 회원은 거부한다" do
    @member.update_columns(withdrawn_at: Time.current)
    post login_member_post_path(slug: @member.slug), params: { password: "password1234" }
    assert_redirected_to login_member_path(slug: @member.slug)
    assert_nil session[:member_id]
  end

  test "승인되지 않은 회원은 거부한다" do
    @member.update!(status: "pending_approval")
    post login_member_post_path(slug: @member.slug), params: { password: "password1234" }
    assert_redirected_to root_path
    assert_nil session[:member_id]
  end
end
