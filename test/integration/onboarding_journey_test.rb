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

  test "public pages omit the default profession after email signup" do
    email = "onboarding-no-profession@example.com"
    post member_signup_path, params: {
      member: { name: "새 회원", email: email, password: PASSWORD, password_confirmation: PASSWORD },
      terms_agree: "1"
    }
    member = Member.find_by!(email: email)
    assert_equal "custom", member.profession

    open_session do |visitor|
      profile = public_profile_path(slug: member.slug)
      %w[editorial grid].each do |layout|
        member.update!(layout_preset: layout)
        visitor.get profile
        visitor.assert_response :success
        assert_not_includes visitor.response.body, "크리에이터"
        visitor.assert_select 'meta[property="og:title"][content=?]', member.name
        if layout == "editorial"
          visitor.assert_select 'script[type="application/ld+json"]' do |scripts|
            person = scripts.map { |script| JSON.parse(script.text) }.find { |data| data["@type"] == "Person" }
            assert person
            assert_not person.key?("jobTitle")
          end
        end
      end

      visitor.get public_profile_card_path(slug: member.slug)
      visitor.assert_response :success
      assert_not_includes visitor.response.body, "크리에이터"

      member.update!(profession: "educator", layout_preset: "editorial")
      visitor.get profile
      visitor.assert_select "body", text: /#{Regexp.escape(member.profession_label)}/
    end
  end

  test "creating a service shows the next task for one request" do
    member = create_member("onboarding-next-task")
    log_in(member)
    services = slug_admin_services_path(slug: member.slug)

    post services, params: { member_service: { title: "첫 상담" } }
    assert_redirected_to services
    follow_redirect!
    assert_select ".shared-flash", count: 1
    assert_select "[data-next-step]" do
      assert_select ".next-step-title", text: "자기소개 50자 넘게 쓰기"
      assert_select 'a[href*="task=bio"]', text: "자기소개 쓰기"
      assert_select "a[href=?]:not([target])", public_profile_path(slug: member.slug), text: "내 페이지 보기"
      assert_select "a[href=?]", slug_admin_dashboard_path(slug: member.slug), text: "대시보드로 돌아가기"
    end

    get services
    assert_select "[data-next-step]", count: 0
  end

  test "failed creation and changes to an existing service do not show a next task" do
    member = create_member("onboarding-service-changes")
    service = member.member_services.create!(title: "첫 상담")
    log_in(member)
    services = slug_admin_services_path(slug: member.slug)
    service_path = slug_admin_service_path(slug: member.slug, id: service)

    post services, params: { member_service: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "[data-next-step]", count: 0

    patch service_path, params: { member_service: { title: "상담 수정" } }
    follow_redirect!
    assert_select "[data-next-step]", count: 0

    patch service_path, params: { member_service: { is_active: 0 }, visibility_toggle: "1" }
    follow_redirect!
    assert_select "[data-next-step]", count: 0

    delete service_path
    follow_redirect!
    assert_select "[data-next-step]", count: 0
  end

  test "creating the final checklist item links to the public page" do
    member = create_member("onboarding-checklist-complete", profile_image: "/icon.png",
      bio: "고객에게 필요한 상담을 제공해 드려요. " * 3, profession: "educator", region: "서울")
    member.member_photos.create!(category: "daily", image: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png"))
    member.member_documents.create!(filename: "경력.txt", category: "career", content_md: "경력 소개")
    log_in(member)

    post slug_admin_services_path(slug: member.slug), params: { member_service: { title: "첫 상담" } }
    follow_redirect!
    assert_select "[data-next-step]" do
      assert_select ".next-step-title", text: "준비 항목을 모두 마쳤어요."
      assert_select "a[href=?]", public_profile_path(slug: member.slug), text: "내 페이지 보기"
      assert_select "a.impd-btn-accent", count: 0
    end
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
