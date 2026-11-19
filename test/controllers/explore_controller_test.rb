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
end
