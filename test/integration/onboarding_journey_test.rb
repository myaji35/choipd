# frozen_string_literal: true

require "test_helper"

class OnboardingJourneyTest < ActionDispatch::IntegrationTest
  PASSWORD = "password1234"

  test "anonymous visitors see the profile photo only as the avatar in both layouts" do
    email = "onboarding-photos@example.com"
    post member_signup_path, params: {
      member: { name: "사진 시험", email: email, password: PASSWORD, password_confirmation: PASSWORD },
      terms_agree: "1"
    }
    member = Member.find_by!(email: email)
    patch slug_admin_profile_photo_path(slug: member.slug), params: {
      image: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png")
    }
    assert_response :see_other
    avatar = member.reload.profile_image
    visitor = open_session
    check_avatar = -> do
      visitor.get public_profile_path(slug: member.slug)
      visitor.assert_response :ok
      visitor.assert_select "img.public-avatar[src=?]", avatar, count: 1
      visitor.assert_select "img[src*='icon.png']", count: 1
    end

    check_avatar.call
    visitor.assert_select "#moments", count: 0
    member.member_photos.create!(category: "daily",
      image: { io: StringIO.new(Rails.root.join("public/icon.png").binread), filename: "work.png", content_type: "image/png" })
    check_avatar.call
    visitor.assert_select "#moments .impd-label-muted", text: "사진 1개"

    member.update!(layout_preset: "grid")
    check_avatar.call
  end

  test "email signup lands on the owner page with a welcome and a next step" do
    email = "onboarding-new@example.com"
    post member_signup_path, params: {
      member: { name: "새 회원", email: email, password: PASSWORD, password_confirmation: PASSWORD, profession: "custom" },
      terms_agree: "1"
    }

    member = Member.find_by!(email: email)
    assert_redirected_to public_profile_path(slug: member.slug)
    follow_redirect!

    assert_owner_service_task(member)
    assert_select "[role=status]", text: /환영합니다, 새 회원님. 이제 페이지를 편집할 수 있어요./
    assert_select "[data-pending-notice]", count: 0
    assert_select "[data-pending-prep]", count: 0
    assert_select ".shared-flash a", text: "기다리는 동안 예시 페이지 보기", count: 0
  end

  test "email signup career task saves a note that anonymous customers can read" do
    email = "onboarding-career@example.com"
    post member_signup_path, params: {
      member: { name: "새 회원", email: email, password: PASSWORD, password_confirmation: PASSWORD, profession: "educator" },
      terms_agree: "1"
    }
    member = Member.find_by!(email: email)
    member.update!(bio: "고객에게 필요한 상담을 제공해 드려요. " * 3, region: "서울", profile_image: "/icon.png")
    member.member_services.create!(title: "첫 상담")
    member.member_photos.create!(category: "daily", image: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png"))

    get public_profile_path(slug: member.slug)
    career_path = slug_admin_editor_path(slug: member.slug, step: 2, from: "checklist", task: "docs", anchor: "career-note")
    assert_select "[data-owner-bar] a[data-owner-next=docs][href=?]", career_path, text: "다음 할 일: 경력 적기"

    career = "2010년부터 상담 교육을 하고 있어요."
    patch slug_admin_editor_update_info_path(slug: member.slug),
      params: { from: "checklist", task: "docs", member: { career_note: career } }
    assert_redirected_to slug_admin_dashboard_path(slug: member.slug)

    open_session do |visitor|
      visitor.get public_profile_path(slug: member.slug)
      visitor.assert_response :success
      visitor.assert_select "body", text: /#{Regexp.escape(career)}/
      visitor.assert_select "[data-owner-bar]", count: 0
    end
  end

  test "owner with a service sees the bio task and a dashboard link in the top navigation" do
    member = create_member("onboarding-service")
    member.member_services.create!(title: "첫 상담", is_active: 1)
    log_in(member)

    get public_profile_path(slug: member.slug)

    dashboard = slug_admin_dashboard_path(slug: member.slug)
    bio_path = slug_admin_editor_path(slug: member.slug, step: 2, from: "checklist", task: "bio", anchor: "bio")
    assert_select "[data-owner-bar] a.owner-bar-action[data-owner-next=bio][href=?]", bio_path, text: "다음 할 일: 자기소개 쓰기"
    assert_select ".impd-topnav-actions a[href=?]", dashboard, text: "내 페이지 관리"

    get root_path

    assert_select ".impd-topnav-actions a[href=?]", public_profile_path(slug: member.slug), text: "내 페이지"
  end

  test "owner bar is absent for anonymous and other member visits" do
    member = create_member("onboarding-owner")
    path = public_profile_path(slug: member.slug)

    get path
    assert_response :success
    assert_select "[data-owner-bar], [data-owner-next]", count: 0

    log_in(create_member("onboarding-visitor"))
    get path
    assert_response :success
    assert_select "[data-owner-bar], [data-owner-next]", count: 0
  end

  test "grid profile also shows the owner bar" do
    member = create_member("onboarding-grid", layout_preset: "grid")
    log_in(member)

    get public_profile_path(slug: member.slug)

    assert_owner_service_task(member)
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
      assert_select "[data-pending-prep]" do |prep|
        ["하는 일 한 가지", "자기소개 두세 줄", "얼굴 사진"].each do |item|
          assert_includes prep.first.text, item
        end
      end
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
    member = create_member_with_checklist_details("onboarding-checklist-complete")
    log_in(member)

    post slug_admin_services_path(slug: member.slug), params: { member_service: { title: "첫 상담" } }
    follow_redirect!
    assert_select "[data-next-step]" do
      assert_select ".next-step-title", text: "준비 항목을 모두 마쳤어요."
      assert_select "a[href=?]", public_profile_path(slug: member.slug), text: "내 페이지 보기"
      assert_select "a.impd-btn-accent", count: 0
    end
  end

  test "owner who completed the checklist sees only the edit link in the owner bar" do
    member = create_member_with_checklist_details("onboarding-owner-complete")
    member.member_services.create!(title: "첫 상담")
    log_in(member)

    get public_profile_path(slug: member.slug)

    assert_select "[data-owner-bar]" do
      assert_select "a", count: 1
      assert_select "a.owner-bar-action[href=?]", slug_admin_dashboard_path(slug: member.slug), text: "내 페이지 고치기"
      assert_select ".owner-bar-more, [data-owner-next]", count: 0
    end
  end

  test "bio form preserves checklist context only for arrivals from the checklist" do
    member = create_member("onboarding-bio-form")
    log_in(member)
    form_path = slug_admin_editor_update_info_path(slug: member.slug)

    get slug_admin_editor_path(slug: member.slug, step: 2, from: "checklist", task: "bio")

    assert_select "form[action=?]", form_path do
      assert_select "input[type=hidden][name=from][value=checklist]"
      assert_select "input[type=hidden][name=task][value=bio]"
      assert_select "button[type=submit]", text: "저장하고 다음 할 일로 →"
      assert_select "#member_bio[placeholder]" do |fields|
        assert_operator fields.first["placeholder"].length, :>=, 50
      end
      assert_select "#member_bio_guide"
    end

    get slug_admin_editor_path(slug: member.slug, step: 2)

    assert_select "form[action=?]", form_path do
      assert_select "input[type=hidden][name=from], input[type=hidden][name=task]", count: 0
      assert_select "button[type=submit]", text: "정보 저장하고 다음 →"
    end
  end

  test "bio and email are required while an unchosen profession stays optional" do
    member = create_member("onboarding-optional-profession", profession: "custom")
    log_in(member)

    get slug_admin_editor_path(slug: member.slug, step: 2)
    assert_response :success
    %w[profession custom_profession].each do |field|
      assert_select "label[for=member_#{field}]", text: /\(선택\)/
      assert_select "label[for=member_#{field}]", text: /\(필수\)/, count: 0
    end
    %w[bio email].each do |field|
      assert_select "label[for=member_#{field}]", text: /\(필수\)/
    end
    assert_select "#member_custom_profession_help", text: "비워 두면 내 페이지에 직업이 안 보여요."
    assert_select '#member_custom_profession[aria-describedby~="member_custom_profession_help"]'
    assert_not_includes response.body, "세 칸만"

    bio = "가" * 60
    patch slug_admin_editor_update_info_path(slug: member.slug),
      params: { member: { bio: bio, profession: "custom", custom_profession: "" } }
    assert_response :redirect
    assert_equal bio, member.reload.bio

    open_session do |visitor|
      visitor.get public_profile_path(slug: member.slug)
      visitor.assert_response :success
      assert_not_includes visitor.response.body, "크리에이터"
    end
  end

  test "saving a checklist bio with a known or unknown task returns to the dashboard" do
    member = create_member("onboarding-bio-save")
    member.member_services.create!(title: "첫 상담")
    log_in(member)

    ["bio", "아무거나"].each do |task|
      patch slug_admin_editor_update_info_path(slug: member.slug),
        params: { from: "checklist", task: task, member: { bio: "가" * 60 } }

      assert_redirected_to slug_admin_dashboard_path(slug: member.slug)
      assert_equal "가" * 60, member.reload.bio
      follow_redirect!
      assert_select "[role=status]", text: "내 정보를 저장했어요. 아래 '다음 할 일'을 이어서 해 보세요."
      assert_select "section.dashboard-next[data-next-task=profile-photo]"
    end
  end

  test "an invalid checklist bio save keeps the arrival banner and form context" do
    member = create_member("onboarding-bio-invalid")
    log_in(member)
    form_path = slug_admin_editor_update_info_path(slug: member.slug)

    patch form_path, params: { from: "checklist", task: "bio", member: { email: "abc" } }

    assert_response :unprocessable_entity
    assert_select ".checklist-arrival a", text: "대시보드로 돌아가기 ←"
    assert_select "form[action=?]", form_path do
      assert_select "input[type=hidden][name=from][value=checklist]"
      assert_select "input[type=hidden][name=task][value=bio]"
      assert_select "button[type=submit]", text: "저장하고 다음 할 일로 →"
    end
  end

  private

  def assert_owner_service_task(member)
    service_path = slug_admin_services_path(slug: member.slug, from: "checklist", task: "services", anchor: "new-service")
    assert_select "[data-owner-bar] a.owner-bar-action[data-owner-next=services][href=?]", service_path, text: "다음 할 일: 서비스 등록하기"
    assert_select "[data-owner-bar] a.owner-bar-more[href=?]", slug_admin_dashboard_path(slug: member.slug), text: "관리 화면 보기"
  end

  def create_member_with_checklist_details(slug)
    member = create_member(slug, profile_image: "/icon.png",
      bio: "고객에게 필요한 상담을 제공해 드려요. " * 3, profession: "educator", region: "서울")
    member.member_photos.create!(category: "daily", image: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png"))
    member.member_documents.create!(filename: "경력.txt", category: "career", content_md: "경력 소개")
    member
  end

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
