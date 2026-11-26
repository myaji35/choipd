require "test_helper"

class PublicSharePreviewTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(name: "공유 회원", email: "share-#{SecureRandom.hex(5)}@example.com",
      slug: "share-#{SecureRandom.hex(5)}", status: "approved")
  end

  test "both layouts show services in the preview when the bio is blank" do
    add_services("A", "B")
    @member.member_services.create!(title: "마감 서비스", sort_order: -1, is_active: 0)

    %w[editorial grid].each do |layout|
      @member.update!(layout_preset: layout)
      get "/#{@member.slug}"
      assert_select 'meta[property="og:description"][content=?]', "하는 일: A · B", count: 1
      assert_select 'meta[name="description"][content=?]', "하는 일: A · B", count: 1
      assert_select 'meta[content*="수료증만 올리면"]', count: 0
    end
  end

  test "a sparse member shares only their name and an invitation to inquire" do
    @member.update!(layout_preset: "editorial")
    get "/#{@member.slug}"
    assert_select 'meta[property="og:title"][content=?]', @member.name
    assert_select 'meta[property="og:description"][content=?]', "#{@member.name}님에게 상담·문의를 남길 수 있는 페이지예요."
    assert_select 'script[type="application/ld+json"]', minimum: 1 do |scripts|
      person = JSON.parse(scripts.first.text)
      assert_equal "Person", person.fetch("@type")
      assert_not person.key?("jobTitle")
    end

    get "/#{@member.slug}/card"
    assert_select "h1", text: @member.name
    assert_not_includes response.body, "크리에이터"
  end

  test "both layouts and the summary card include the registered profession in the title" do
    @member.update!(profession: "educator")
    title = "#{@member.name} · #{@member.profession_label}"
    add_services("A")
    get "/#{@member.slug}/card"
    assert_select 'meta[property="og:description"][content=?]', "하는 일: A", count: 1
    assert_select 'meta[property="og:title"][content=?]', title
    assert_select "title", text: "#{title} | imPD"

    %w[editorial grid].each do |layout|
      @member.update!(layout_preset: layout)
      get "/#{@member.slug}"
      assert_select 'meta[property="og:title"][content=?]', title
      assert_select "title", text: "#{title} | imPD"
    end
  end

  test "preview lists the first three services and counts the rest" do
    add_services("A", "B", "C", "D", "E")
    get "/#{@member.slug}"
    assert_select 'meta[property="og:description"][content=?]', "하는 일: A · B · C 외 2개"
  end

  test "preview gives services priority and ends the bio at a sentence boundary" do
    @member.update!(bio: "글쓰기를 가르칩니다. #{"가" * 300}")
    add_services("A")
    get "/#{@member.slug}"
    assert_select 'meta[property="og:description"][content=?]', "하는 일: A — 글쓰기를 가르칩니다."
  end

  test "service titles are escaped once in metadata" do
    add_services('<b>"상담"</b>')
    get "/#{@member.slug}"
    assert_select 'meta[property="og:description"][content=?]', '하는 일: <b>"상담"</b>'
    assert_includes response.body, 'content="하는 일: &lt;b&gt;&quot;상담&quot;&lt;/b&gt;"'
  end

  private

  def add_services(*titles)
    titles.each_with_index do |title, order|
      @member.member_services.create!(title: title, is_active: 1, sort_order: order)
    end
  end
end
