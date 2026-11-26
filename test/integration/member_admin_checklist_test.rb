require "test_helper"
require "uri"

class MemberAdminChecklistTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_member
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    @dashboard_path = slug_admin_dashboard_path(slug: @member.slug)
    @photo_path = slug_admin_profile_photo_path(slug: @member.slug)
    @editor_path = slug_admin_editor_path(slug: @member.slug, step: 2, anchor: "profile-photo")
  end

  test "work photo checklist selects work and regular uploads select daily" do
    path = slug_admin_editor_path(slug: @member.slug, step: 1, tab: "media")

    get path, params: { from: "checklist", task: "media" }
    assert_select "select[data-photo-upload-category] option[selected][value=workshop]", count: 1
    assert_select "select[data-photo-upload-category] option", count: 3 do |options|
      assert_equal %w[일상 작업 이력], options.map(&:text)
    end

    get path
    assert_select "select[data-photo-upload-category] option[selected][value=daily]", count: 1

    get path, params: { from: "checklist", task: "docs" }
    assert_select "select[data-photo-upload-category] option[selected][value=daily]", count: 1
  end

  test "checklist save buttons follow their own fields" do
    path = slug_admin_editor_path(slug: @member.slug, step: 2)

    get path, params: { from: "checklist", task: "bio" }
    assert_select "#bio [data-task-save=bio] button[type=submit]", count: 1
    assert_select "[data-task-save=profession-region]", count: 0
    assert_select "[data-task-save=docs]", count: 0
    assert_operator response.body.index('data-task-save="bio"'), :<, response.body.index('id="profession-region"')

    get path, params: { from: "checklist", task: "profession-region" }
    assert_select "#profession-region + [data-task-save=profession-region] button[type=submit]", count: 1
    assert_select "[data-task-save=bio]", count: 0
    assert_select "[data-task-save=docs]", count: 0
    save_position = response.body.index('data-task-save="profession-region"')
    assert_operator response.body.index('id="member_region"'), :<, save_position
    assert_operator save_position, :<, response.body.index('name="member[email]"')

    get path, params: { from: "checklist", task: "profile-photo" }
    assert_select "[data-task-save]", count: 0

    get path, params: { task: "bio" }
    assert_select "[data-task-save]", count: 0

    get path, params: { task: "docs" }
    assert_select "[data-task-save]", count: 0
  end

  test "failed checklist save keeps the task button and hidden fields" do
    patch slug_admin_editor_update_info_path(slug: @member.slug),
      params: { from: "checklist", task: "bio", member: { bio: "소개", email: "" } }

    assert_response :unprocessable_entity
    assert_select "form.editor-fields" do
      assert_select "input[type=hidden][name=from][value=checklist]"
      assert_select "input[type=hidden][name=task][value=bio]"
      assert_select "[data-task-save=bio] button[type=submit]", count: 1
    end
  end

  test "media gallery excludes the profile photo from cards and counts" do
    patch @photo_path, params: { image: upload_image }
    path = slug_admin_editor_path(slug: @member.slug, step: 1, tab: "media")

    get path
    assert_select "[data-controller=member-photo-card]", count: 0
    assert_select "[data-tab-id=media] div", text: "사진·영상 0개"
    assert_select "[data-profile-photo-note]", count: 1

    get @editor_path
    assert_select '[aria-labelledby="editor-added-materials-title"] li span', text: "사진·영상 0개"

    photo = create_photo(@member)
    get path
    assert_select "[data-controller=member-photo-card]", count: 1
    assert_select "[data-member-photo-card-id-value=?]", photo.id.to_s
    assert_select "[data-tab-id=media] div", text: "사진·영상 1개"
    assert_select "span", text: "갤러리 · 1장"
    assert_select "[data-profile-photo-note]", count: 1
  end

  test "media gallery lists photos without a profile photo note when none is selected" do
    create_photo(@member)
    get slug_admin_editor_path(slug: @member.slug, step: 1, tab: "media")

    assert_select "[data-controller=member-photo-card]", count: 1
    assert_select "[data-profile-photo-note]", count: 0
  end

  test "each dashboard action opens its destination and shows a return link" do
    get @dashboard_path
    assert_response :success
    actions = {
      "사진 올리기" => [ "profile-photo", "프로필 사진 올리기" ],
      "자기소개 쓰기" => [ "bio", "자기소개 50자 넘게 쓰기" ],
      "직업·지역 정하기" => [ "profession-region", "직업과 지역 적기" ],
      "작업 사진 올리기" => [ "media", "작업 사진·사례 올리기" ],
      "서비스 등록하기" => [ "new-service", "서비스 1개 넣기" ],
      "경력 적기" => [ "career-note", "경력 적기" ]
    }
    links = css_select('a[href*="from=checklist"]').to_h { |link| [ link.text.strip, link["href"] ] }
    assert_equal actions.keys.sort, links.keys.sort

    actions.each do |action, (anchor, label)|
      uri = URI.parse(links.fetch(action))
      assert_equal anchor, uri.fragment
      uri.fragment = nil
      get uri.to_s
      assert_response :success
      assert_select "##{anchor}.checklist-target", count: 1
      assert_select ".checklist-arrival", text: /#{Regexp.escape(label)}/ do
        assert_select "a[href=?]", @dashboard_path, text: "대시보드로 돌아가기 ←"
      end
      if anchor == "career-note"
        assert_includes URI.decode_www_form(uri.query), [ "step", "2" ]
        assert_select "#career-note.checklist-target textarea#member_career_note", count: 1
        assert_select "[data-task-save=docs] button[type=submit]", count: 1
      end
      if anchor == "media"
        assert_select "##{anchor}:not([hidden])", count: 1
        assert_select "[aria-controls=?][aria-pressed=true]", anchor, count: 1
      end
    end
  end

  test "arrival banner uses only whitelisted task labels" do
    task = "untrusted-checklist-label"
    [
      slug_admin_editor_path(slug: @member.slug, step: 2, from: "checklist", task: task),
      slug_admin_services_path(slug: @member.slug, from: "checklist", task: task)
    ].each do |path|
      get path
      assert_response :success
      assert_select ".checklist-arrival a[href=?]", @dashboard_path
      assert_not_includes response.body, task
    end

    get @editor_path
    assert_select ".checklist-arrival", count: 0
    assert_select "#profile-photo input[type=file][accept='image/*']", count: 1
    assert_select "#profile-photo input[type=file][capture]", count: 0
    assert_select '#profile-photo form[data-action="submit->editor-info#submitProfilePhoto"]', count: 1
    assert_select ".profile-photo-choices", count: 0
  end

  test "upload completes the profile photo task and leaves the work photo task open" do
    @member.update!(bio: "가" * 60)
    @member.member_services.create!(title: "첫 상담")
    assert_difference -> { @member.member_photos.count }, 1 do
      patch @photo_path, params: { image: upload_image, from: "checklist" }
    end
    assert_redirected_to @dashboard_path
    photo = @member.member_photos.last
    assert_equal "people", photo.category
    assert_equal rails_blob_path(photo.image, only_path: true), @member.reload.profile_image

    follow_redirect!
    assert_select "[role=status]", text: /프로필 사진을 올렸어요/
    assert_select "[role=status]", text: /다음 할 일/
    assert_select '.dashboard-next[data-next-task="profession-region"]'
    assert_select ".dashboard-next summary", text: /6개 중 3개/
    assert_select '.dashboard-next details a[href*="task=media"]', text: "작업 사진 올리기"
    assert_select 'a[href*="task=profile-photo"]', count: 0
    assert_select "[data-all-done-actions]", count: 0
  end

  test "upload outside the checklist returns to the profile photo editor" do
    patch @photo_path, params: { image: upload_image }

    assert_redirected_to @editor_path
    follow_redirect!
    assert_select "[role=status]", text: "프로필 사진을 바꿨어요."
  end

  test "profile photo checklist explains how to choose an existing phone photo" do
    get slug_admin_editor_path(slug: @member.slug, step: 2, from: "checklist", task: "profile-photo")

    assert_response :success
    assert_select "#profile-photo-hint", text: /휴대폰에 있는 사진을 골라도 돼요/
    assert_select "#profile-photo form[data-turbo=false]:not([data-action])" do
      assert_select 'input[type=file][data-action="change->editor-info#uploadProfilePhoto"]', count: 1
    end
  end

  test "invalid upload preserves the existing profile photo and shows a Korean error" do
    original = "https://example.com/avatar.png"
    @member.update!(profile_image: original)
    assert_no_difference -> { @member.member_photos.count } do
      patch @photo_path, params: { image: fixture_file_upload("linkedin/profile.txt", "text/plain") }
    end
    assert_redirected_to @editor_path
    assert_equal original, @member.reload.profile_image
    follow_redirect!
    assert_select "#profile-photo [role=alert]", text: /지원되는 이미지 형식/
  end

  test "an uploaded photo can be selected without making another photo" do
    photo = create_photo(@member)
    get @editor_path
    assert_select ".profile-photo-choices input[name=photo_id][value=?]", photo.id.to_s, count: 1

    assert_no_difference -> { @member.member_photos.count } do
      patch @photo_path, params: { photo_id: photo.id }
    end
    assert_redirected_to @editor_path
    assert_equal rails_blob_path(photo.image, only_path: true), @member.reload.profile_image
    follow_redirect!
    assert_select "#profile-photo img.profile-photo-preview[src=?]", @member.profile_image
  end

  test "another member's photo cannot be selected" do
    photo = create_photo(create_member)
    patch @photo_path, params: { photo_id: photo.id }
    assert_redirected_to @editor_path
    assert_nil @member.reload.profile_image
    follow_redirect!
    assert_select "#profile-photo [role=alert]", text: "선택한 사진을 사용할 수 없어요."
  end

  test "only checklist arrivals include upload return URLs" do
    %w[docs media].zip(%w[doc photo], %i[slug_admin_documents_path slug_admin_photos_path]).each do |tab, uploader, route|
      [nil, "checklist"].each do |from|
        get slug_admin_editor_path(slug: @member.slug, step: 1, tab: tab, from: from, task: tab)
        assert_response :ok
        if tab == "docs"
          assert_select "#docs:not([hidden]).checklist-target", count: 1
          assert_select "[aria-controls=docs][aria-pressed=true]", count: 1
          assert_select "[data-career-note-link][href*='step=2'][href$='#career-note']", count: 1
        end
        prefix = "data-member-#{uploader}-uploader"
        create_url = public_send(route, slug: @member.slug, format: :json, from: from)
        assert_select "##{tab} [#{prefix}-create-url-value=?]", create_url
        if from
          assert_select "##{tab} [#{prefix}-done-url-value=?]", @dashboard_path
        else
          assert_select "[#{prefix}-done-url-value]", count: 0
        end
      end
    end
  end

  test "mixed checklist document uploads leave no completion notice in the session" do
    path = slug_admin_documents_path(slug: @member.slug, format: :json, from: "checklist")
    editor_path = slug_admin_editor_path(slug: @member.slug, step: 1, tab: "docs", from: "checklist")
    get editor_path

    post path, params: { filename: "career.txt", content: "시험용 경력 글입니다." }, as: :json
    assert_response :created
    assert_nil flash[:notice]
    post path, params: { filename: "empty.txt", content: "" }, as: :json
    assert_response :unprocessable_entity

    get editor_path
    assert_select "[role=status]", text: /경력 글을 올렸어요/, count: 0
  end

  test "mixed checklist photo uploads leave no completion notice in the session" do
    path = slug_admin_photos_path(slug: @member.slug, format: :json, from: "checklist")
    editor_path = slug_admin_editor_path(slug: @member.slug, step: 1, tab: "media", from: "checklist")
    get editor_path

    post path, params: { files: [upload_image] }
    assert_response :created
    assert_nil flash[:notice]
    post path, params: { files: [fixture_file_upload("linkedin/profile.txt", "text/plain")] }
    assert_response :unprocessable_entity

    get editor_path
    assert_select "[role=status]", text: /작업 사진을 올렸어요/, count: 0
  end

  test "dashboard shows only the matching completion notice for the current request" do
    notices = {
      "photos" => "작업 사진을 올렸어요. 아래에서 다음에 할 일을 확인해 보세요.",
      "docs" => "경력 글을 올렸어요. 아래에서 다음에 할 일을 확인해 보세요."
    }
    [ "photos", "docs", "unknown", [ "photos" ], nil ].each do |done|
      get @dashboard_path, params: { done: done }
      assert_response :ok
      notices.each do |key, message|
        assert_select "[role=status]", text: message, count: key == done ? 1 : 0
      end
    end
  end

  test "completed checklist offers sharing actions" do
    @member.update!(bio: "가" * 60, profession: "educator", region: "서울", profile_image: "/icon.png")
    @member.member_services.create!(title: "첫 상담")
    create_photo(@member)
    @member.member_documents.create!(filename: "career.txt", category: "career", content_md: "시험용 글")

    get @dashboard_path

    assert_select "[data-all-done-actions]" do
      assert_select "[data-controller=clipboard-copy][data-clipboard-copy-label-value='주소 복사']" do
        assert_select "button[data-action='clipboard-copy#copy'][data-clipboard-copy-target=button]", text: "주소 복사"
        assert_select "input[readonly][data-clipboard-copy-target=source]", count: 1 do |sources|
          url = URI.parse(sources.first["value"])
          assert_kind_of URI::HTTP, url
          assert_equal "/#{@member.slug}", url.path
        end
        assert_select "[role=status][data-clipboard-copy-target=status]", count: 1
      end
      assert_select "a[href=?][target=_blank]", "/#{@member.slug}", text: "내 페이지 보기"
    end
  end

  test "bio checklist shows the remaining characters only on checklist arrival" do
    path = slug_admin_editor_path(slug: @member.slug, step: 2)
    task_selector = "[data-controller~='editor-info'][data-editor-info-task-value='bio']"
    get path, params: { from: "checklist", task: "bio" }
    assert_select "#member_bio_count", text: /50자만 더 쓰면 이 할 일이 끝나요./
    assert_select task_selector, count: 1

    @member.update!(bio: "가" * 24)
    get path, params: { from: "checklist", task: "bio" }
    assert_select "#member_bio_count", text: /26자만 더 쓰면 이 할 일이 끝나요./

    @member.update!(bio: "")
    get path, params: { task: "bio" }
    assert_select "#member_bio_count", text: /20자를 넘기면 내 페이지를 공개할 수 있어요./
    assert_select "[data-editor-info-task-value]", count: 0
  end

  test "bio checklist save explains what remains only below 50 characters" do
    assert_checklist_save "bio", { bio: "가" * 24 },
      "저장했어요. 자기소개가 지금 24자예요. 26자만 더 쓰면 이 할 일이 끝나요."
    assert_equal "가" * 24, @member.reload.bio
    assert_checklist_save "bio", { bio: "가" * 60 }
  end

  test "profession and region checklist save identifies the missing fields" do
    assert_checklist_save "profession-region", { profession: "educator", region: "" },
      "저장했어요. 지역도 적으면 이 할 일이 끝나요."
    assert_checklist_save "profession-region", { profession: "custom", custom_profession: "", region: "서울" },
      "저장했어요. 직업도 고르면 이 할 일이 끝나요."
    assert_checklist_save "profession-region", { profession: "", region: "" },
      "저장했어요. 직업과 지역을 적으면 이 할 일이 끝나요."
    assert_checklist_save "profession-region", { profession: "educator", region: "서울" }
  end

  test "career checklist can be completed without uploading a document" do
    @member.update!(bio: "가" * 60, profession: "educator", region: "서울", profile_image: "/icon.png")
    @member.member_services.create!(title: "첫 상담")
    create_photo(@member)

    assert_checklist_save "docs", { career_note: " " },
      "저장했어요. 경력 칸이 비어 있어요. 한 줄만 적어도 이 할 일이 끝나요."
    assert_select '.dashboard-next[data-next-task="docs"]'
    assert_select "[data-all-done-actions]", count: 0

    assert_checklist_save "docs", { career_note: "시험 경력 10년" },
      "경력을 저장했어요. 아래에서 다음에 할 일을 확인해 보세요."
    assert_equal "시험 경력 10년", @member.reload.career_note
    assert_empty @member.member_documents
    assert_select ".dashboard-next", text: /준비 항목을 모두 마쳤어요/
    assert_select "[data-all-done-actions]", count: 1
  end

  test "an uploaded document still completes the career task" do
    @member.member_documents.create!(filename: "career.txt", category: "career", content_md: "시험용 글")

    assert_checklist_save "docs", { career_note: "" }
    assert_select '.dashboard-next a[href*="task=docs"]', count: 0
    assert_select ".dashboard-next summary", text: /6개 중 1개/
  end

  private

  def assert_checklist_save(task, attributes, notice = "내 정보를 저장했어요. 아래 '다음 할 일'을 이어서 해 보세요.")
    patch slug_admin_editor_update_info_path(slug: @member.slug),
      params: { from: "checklist", task: task, member: attributes }
    assert_redirected_to @dashboard_path
    follow_redirect!
    assert_select "[role=status]", text: notice
  end

  def create_member
    slug = "checklist-#{SecureRandom.hex(4)}"
    Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug, status: "approved",
      business_type: "individual", password: "password1234", password_confirmation: "password1234")
  end

  def create_photo(member)
    member.member_photos.create!(category: "daily", image: upload_image)
  end

  def upload_image
    fixture_file_upload(Rails.root.join("public/icon.png"), "image/png")
  end
end
