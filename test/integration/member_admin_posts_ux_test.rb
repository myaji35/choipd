require "test_helper"

class MemberAdminPostsUxTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_member
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    @posts_path = slug_admin_posts_path(slug: @member.slug)
  end

  test "소식 목록은 회원용 문구와 접힌 수정 칸을 보여 준다" do
    @member.member_posts.create!(title: "상담 안내", content: "이번 주 무료 상담", category: "공지",
      is_published: 1, published_at: Time.utc(2026, 11, 2, 18))
    @member.member_posts.create!(title: "준비 중인 소식", content: "다음 주 일정", is_published: 0)

    get @posts_path

    assert_response :ok
    %w[POSTS 발행 LIVE 썸네일 카테고리].each { |word| assert_not_includes response.body, word }
    assert_not_includes response.body, "소식 관리"
    assert_select "h1", count: 1, text: "소식"
    assert_select "h2", text: "내 소식"
    assert_select "#new-post h2", text: "새 소식 쓰기"
    assert_select "article details", count: 2
    assert_select "details[open]", count: 0
    assert_select "article span", text: "보이는 중"
    assert_select "article span", text: "나만 보기"
    assert_select "article p", text: "2026.11.03 03:00에 올림 · 공지"
    assert_select "article p", text: "아직 고객에게 보이지 않아요"
    assert_select "article .post-preview", text: "이번 주 무료 상담"
    assert_select "#new-post input[type=checkbox][name='member_post[is_published]'][checked]", count: 1
    assert_select "article input[name='member_post[is_published]']", count: 0
  end

  test "새 소식은 체크 여부에 맞게 저장된다" do
    { "1" => "내 페이지에 바로 보여요", "0" => "아직 나만 볼 수 있어요" }.each do |visibility, notice|
      title = "새 상담 안내 #{visibility}"
      assert_difference -> { @member.member_posts.count }, 1 do
        post @posts_path, params: { member_post: { title: title, content: "이번 주 무료 상담", is_published: visibility } }
      end

      assert_redirected_to @posts_path
      assert_includes flash[:notice], notice
      saved_post = @member.member_posts.find_by!(title: title)
      assert_equal visibility.to_i, saved_post.is_published
      visibility == "1" ? assert_not_nil(saved_post.published_at) : assert_nil(saved_post.published_at)
    end
  end

  test "제목을 고쳐도 이미 저장된 이미지와 공개 상태를 유지한다" do
    published_at = Time.utc(2026, 11, 2, 18)
    thumbnail_url = "https://example.com/post.jpg"
    saved_post = @member.member_posts.create!(title: "상담", content: "상담 일정",
      is_published: 1, published_at: published_at, thumbnail_url: thumbnail_url)

    patch slug_admin_post_path(slug: @member.slug, id: saved_post), params: { member_post: { title: "무료 상담" } }

    assert_redirected_to @posts_path
    saved_post.reload
    assert_equal "무료 상담", saved_post.title
    assert_equal thumbnail_url, saved_post.thumbnail_url
    assert_equal 1, saved_post.is_published
    assert_equal published_at, saved_post.published_at
  end

  test "수정 저장에 실패하면 해당 글의 수정 칸만 열린다" do
    saved_post = @member.member_posts.create!(title: "상담", content: "상담 일정")
    @member.member_posts.create!(title: "강의", content: "강의 일정")
    edit_path = slug_admin_post_path(slug: @member.slug, id: saved_post)

    patch edit_path, params: { member_post: { title: "", content: "바꾼 상담 일정" } }

    assert_response :unprocessable_entity
    assert_select "article details[open]", count: 1 do
      assert_select "form[action=?] textarea", edit_path, text: "바꾼 상담 일정"
    end
  end

  test "소식이 없으면 새 글 쓰기를 안내한다" do
    get @posts_path

    assert_response :ok
    assert_includes response.body, "아직 올린 소식이 없어요"
  end

  private

  def create_member
    slug = "posts-ux-#{SecureRandom.hex(4)}"
    Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug, status: "approved",
      business_type: "individual", password: "password1234", password_confirmation: "password1234")
  end
end
