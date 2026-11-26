# frozen_string_literal: true

require "test_helper"

class OnboardingJourneyTest < ActionDispatch::IntegrationTest
  PASSWORD = "password1234"

  test "email signup lands on the owner page with a welcome and a next step" do
    email = "onboarding-new@example.com"
    post member_signup_path, params: {
      member: { name: "새 회원", email: email, password: PASSWORD, password_confirmation: PASSWORD, profession: "custom" },
      terms_agree: "1"
    }

    member = Member.find_by!(email: email)
    assert_redirected_to public_profile_path(slug: member.slug)
    follow_redirect!

    assert_select "[data-owner-bar] a[href=?]", slug_admin_dashboard_path(slug: member.slug), text: "내 페이지 채우기"
    assert_select "[role=status]", text: /환영합니다, 새 회원님. 이제 페이지를 편집할 수 있어요./
    assert_select "[data-pending-notice]", count: 0
    assert_select ".shared-flash a", text: "기다리는 동안 예시 페이지 보기", count: 0
  end

  test "owner with a service sees an edit link and a dashboard link in the top navigation" do
    member = create_member("onboarding-service")
    member.member_services.create!(title: "첫 상담", is_active: 1)
    log_in(member)

    get public_profile_path(slug: member.slug)

    dashboard = slug_admin_dashboard_path(slug: member.slug)
    assert_select "[data-owner-bar] a[href=?]", dashboard, text: "내 페이지 고치기"
    assert_select ".impd-topnav-actions a[href=?]", dashboard, text: "내 페이지 관리"

    get root_path

    assert_select ".impd-topnav-actions a[href=?]", public_profile_path(slug: member.slug), text: "내 페이지"
  end

  test "owner bar is absent for anonymous and other member visits" do
    member = create_member("onboarding-owner")
    path = public_profile_path(slug: member.slug)

    get path
    assert_response :success
    assert_select "[data-owner-bar]", count: 0

    log_in(create_member("onboarding-visitor"))
    get path
    assert_response :success
    assert_select "[data-owner-bar]", count: 0
  end

  test "grid profile also shows the owner bar" do
    member = create_member("onboarding-grid", layout_preset: "grid")
    log_in(member)

    get public_profile_path(slug: member.slug)

    assert_select "[data-owner-bar] a[href=?]", slug_admin_dashboard_path(slug: member.slug), text: "내 페이지 채우기"
  end

  test "email signup and login forms disable Turbo" do
    get member_signup_path
    assert_select "form[action='/auth/signup'][data-turbo=false]"

    get member_login_path
    assert_select "form[action='/auth/login'][data-turbo=false]"
  end

  test "pending member receives guidance and cannot access a profile or dashboard" do
    member = create_member("onboarding-pending", status: "pending_approval")
    log_in(member)

    assert_redirected_to root_path
    assert_nil request.session[:member_id]
    follow_redirect!

    example_path = css_select(".impd-topnav-links a").find { |link| link.text == "예시" }["href"]
    assert_select "[data-pending-notice]", text: /승인을 기다리는 중이에요/ do
      assert_select "a[href=?]", example_path, text: "기다리는 동안 예시 페이지 보기"
    end

    get public_profile_path(slug: member.slug)
    assert_response :not_found

    get slug_admin_dashboard_path(slug: member.slug)
    assert_redirected_to login_member_path(slug: member.slug)
  end

  private

  def create_member(slug, **attributes)
    Member.create!({
      name: "온보딩 회원", email: "#{slug}@example.com", slug: slug,
      status: "approved", profession: "custom", password: PASSWORD
    }.merge(attributes))
  end

  def log_in(member)
    post member_login_path, params: { email: member.email, password: PASSWORD }
  end
end
