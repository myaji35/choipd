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

  test "each dashboard action opens its destination and shows a return link" do
    get @dashboard_path
    assert_response :success
    actions = {
      "사진 올리기" => [ "profile-photo", "프로필 사진 올리기" ],
      "자기소개 쓰기" => [ "bio", "자기소개 50자 넘게 쓰기" ],
      "직업·지역 정하기" => [ "profession-region", "직업과 지역 적기" ],
      "작업 사진 올리기" => [ "media", "작업 사진·사례 올리기" ],
      "서비스 등록하기" => [ "new-service", "서비스 1개 넣기" ],
      "경력 글 올리기" => [ "docs", "경력을 적은 글 올리기" ]
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
      if %w[media docs].include?(anchor)
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

  private

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
