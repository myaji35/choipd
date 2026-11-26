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

end
