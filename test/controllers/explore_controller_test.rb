require "test_helper"

class ExploreControllerTest < ActionDispatch::IntegrationTest
  test "profession filters retain other profession chips" do
    %w[insurance_agent freelancer].each do |profession|
      Member.create!(name: profession, email: "#{profession}@example.com", slug: profession.tr("_", "-"),
        status: "approved", business_type: "individual", profession: profession,
        password: "password1234", password_confirmation: "password1234")
    end

    get explore_path(profession: "insurance_agent")

    assert_response :success
    assert_select "a.explore-chip[href*='freelancer']", text: /프리랜서/
    assert_select "a.explore-chip[aria-pressed='true']", text: /보험 설계사/
  end
  test "legacy creator values and custom select the same single labeled group" do
    [nil, "custom", "크리에이터", "자유 입력", "educator"].each_with_index do |profession, index|
      Member.create!(name: "분야 회원 #{index}", email: "group-#{index}@example.com",
        slug: "profession-group-#{index}", status: "approved", region: "서울 성북",
        profession: profession, password: "password1234")
    end

    %w[크리에이터 custom].each do |key|
      get explore_path(profession: key)
      assert_response :success
      assert_select ".explore-chip[aria-pressed='true']", text: /크리에이터\s+4/, count: 1
      assert_select ".explore-chip", text: /크리에이터/, count: 1
      assert_select ".explore-grid > .impd-member-card", count: 4
      assert_select ".explore-result-heading", text: /크리에이터 — 4명/
      assert_select ".explore-filter-row", count: 1
    end
  end

  test "a known profession with no public members shows the empty state" do
    create_member("Public author", profession: "author")
    create_member("Pending realtor", profession: "realtor", status: "pending_approval")

    get explore_path(profession: "realtor")

    assert_response :success
    assert_select ".explore-chip[aria-pressed='true']", text: /공인중개사\s+0/
    assert_select ".explore-result-heading", text: /공인중개사 — 0명/
    assert_select ".explore-grid > .impd-member-card", count: 0
    assert_select ".shared-empty h2", text: "조건에 맞는 회원이 없어요"
  end

  test "an unknown profession shows all public members" do
    create_member("Public author", profession: "author")

    get explore_path(profession: "unknown")

    assert_response :success
    assert_select ".explore-chip[aria-pressed='true']", text: /전체/
    assert_select ".explore-grid > .impd-member-card", count: 1
  end

  test "each member gets their newest eligible cover despite a busier gallery" do
    busy = create_member("Busy member")
    quiet = create_member("Quiet member")
    base_time = 2.days.ago
    older_cover = create_photo(quiet, uploaded_at: base_time)
    photos = Array.new(20) { |index| create_photo(busy, uploaded_at: base_time + (index + 1).minutes) }
    portrait = create_photo(busy, uploaded_at: base_time + 21.minutes)
    busy.update!(profile_image: portrait.display_url)
    create_photo(busy, uploaded_at: base_time + 22.minutes, filename: "video.mp4", content_type: "video/mp4")

    get explore_path

    assert_response :success
    assert_select '.impd-member-card[aria-label="Quiet member 페이지 보기"] .impd-member-cover img' do |images|
      assert_equal [older_cover.thumbnail_url], images.map { |image| image["src"] }
    end
    assert_select '.impd-member-card[aria-label="Busy member 페이지 보기"] .impd-member-cover img' do |images|
      assert_equal [photos.last.thumbnail_url], images.map { |image| image["src"] }
    end
  end

  private

  def create_member(name, profession: "author", status: "approved")
    slug = name.parameterize
    Member.create!(name: name, email: "#{slug}@example.com", slug: slug,
      status: status, profession: profession, password: "password1234")
  end

  def create_photo(member, uploaded_at:, filename: "cover.jpg", content_type: "image/jpeg")
    member.member_photos.create!(uploaded_at: uploaded_at, image: {
      io: StringIO.new("test attachment"), filename: filename, content_type: content_type, identify: false
    })
  end
end
