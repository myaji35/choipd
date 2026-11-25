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
    assert_select "#profile-photo input[type=file][accept='image/*'][capture=user]", count: 1
    assert_select ".profile-photo-choices", count: 0
  end

  test "upload sets the profile image and completes both photo checklist items" do
    assert_difference -> { @member.member_photos.count }, 1 do
      patch @photo_path, params: { image: upload_image, from: "checklist" }
    end
    assert_redirected_to @dashboard_path
    photo = @member.member_photos.last
    assert_equal "people", photo.category
    assert_equal rails_blob_path(photo.image, only_path: true), @member.reload.profile_image

    follow_redirect!
    assert_select "[role=status]", text: /프로필 사진을 바꿨어요/
    assert_select 'a[href*="task=profile-photo"], a[href*="task=media"]', count: 0
    assert_select 'a[href*="task=bio"]', text: "자기소개 쓰기"
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
