require "test_helper"

class MemberAccessEnforcementTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "정지 회원은 Google 로그인으로 회원 세션을 얻거나 편집할 수 없다" do
    member = create_member(status: "suspended")

    google_sign_in(member)

    assert_redirected_to root_path
    assert_equal "정지된 계정입니다. 관리자에게 문의해 주세요.", flash[:alert]
    assert_nil request.session[:member_id]
    assert_nil member.reload.last_sign_in_at

    get slug_admin_dashboard_path(slug: member.slug)

    assert_redirected_to login_member_path(slug: member.slug)
  end

  test "운영자가 정지시키면 기존 회원 세션의 다음 편집 요청에서 로그아웃된다" do
    member = create_member(status: "approved")
    browser = open_session
    browser.post member_login_path, params: { email: member.email, password: "password1234" }
    assert_equal member.id, browser.request.session[:member_id]
    browser.get slug_admin_dashboard_path(slug: member.slug)
    browser.assert_response :success

    sign_in create_admin
    post suspend_admin_member_path(member)
    assert_redirected_to admin_member_path(member)
    assert_equal "suspended", member.reload.status

    browser.get slug_admin_dashboard_path(slug: member.slug)
    browser.assert_redirected_to root_path
    assert_equal "정지된 계정입니다. 관리자에게 문의해 주세요.", browser.flash[:alert]
    assert_nil browser.request.session[:member_id]

    post activate_admin_member_path(member)
    assert_equal "approved", member.reload.status

    browser.get slug_admin_dashboard_path(slug: member.slug)
    browser.assert_redirected_to login_member_path(slug: member.slug)
  end

  test "승인된 미탈퇴 회원만 공개 프로필을 표시한다" do
    %w[pending_approval rejected suspended].each do |status|
      member = create_member(status: status)
      get "/#{member.slug}"
      assert_response :not_found
    end

    member = create_member(status: "approved")
    get "/#{member.slug}"
    assert_response :ok

    member.update!(withdrawn_at: Time.current)
    get "/#{member.slug}"
    assert_response :not_found
  end

  test "운영자는 정지 회원 대시보드에 대리 접속할 수 있다" do
    member = create_member(status: "suspended")
    sign_in create_admin

    get slug_admin_dashboard_path(slug: member.slug)

    assert_response :ok
    assert_select ".admin-impersonation-banner", text: /운영자 권한으로 #{member.name}님/
  end

  test "승인 대기 회원은 Google 로그인 시 승인 안내를 받는다" do
    member = create_member(status: "pending_approval")

    google_sign_in(member)

    assert_redirected_to root_path
    assert_includes flash[:notice], "승인을 기다리는 중이에요"
    assert_nil request.session[:member_id]
  end

  test "정지 회원과 이메일이 같은 운영자는 Google 로그인으로 운영자 세션을 얻는다" do
    member = create_member(status: "suspended")
    create_admin(email: member.email)

    google_sign_in(member)

    assert_redirected_to admin_root_path
    assert_nil request.session[:member_id]
    follow_redirect!
    assert_response :ok
  end

  private

  def create_member(status:)
    slug = "access-#{status.tr('_', '-')}"
    Member.create!(name: "접근 테스트 회원", email: "#{slug}@example.test", slug: slug, status: status,
      business_type: "individual", profession: "custom", password: "password1234")
  end

  def create_admin(email: "access-admin@example.test")
    AdminUser.create!(email: email, password: "password1234", role: "admin")
  end

  def google_sign_in(member)
    original_test_mode = OmniAuth.config.test_mode
    original_auth = OmniAuth.config.mock_auth[:google_oauth2]
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(:google_oauth2, uid: "google-#{member.slug}", info: { email: member.email, name: member.name })
    post "/auth/google_oauth2"
    assert_redirected_to "/auth/google_oauth2/callback"
    follow_redirect!
  ensure
    OmniAuth.config.test_mode = original_test_mode
    OmniAuth.config.mock_auth[:google_oauth2] = original_auth
  end
end
