require "test_helper"

class NaverPeople::CrossCheckTest < ActiveSupport::TestCase
  test "checks site registrations and delegates mismatches to the LinkedIn comparison" do
    member = Member.create!(name: "가상 이름", email: "cross-check@example.test", slug: "cross-check",
      social_links: { "blog" => "http://www.example.test/MyBlog/" }.to_json)
    naver = ProfileAccount.create!(platform: "naver_people", display_name: member.name, member: member)
    naver.profile_snapshots.create!(captured_at: Time.current, data: { "people" => {
      "blog" => "https://EXAMPLE.test/myblog",
      "peopleOffice" => [ { "name" => "한빛랩", "position" => "대표", "current" => "Y" } ]
    } })
    linkedin = ProfileAccount.create!(platform: "linkedin", display_name: member.name, member: member,
      profile_url: "https://linkedin.example/in/profile")

    check = NaverPeople::CrossCheck.new(naver)
    assert_nil check.linkedin_mismatches
    assert_includes check.sites, { source: "imPD", url: "http://www.example.test/MyBlog/", registered: true }
    assert_includes check.sites, { source: "LinkedIn", url: linkedin.profile_url, registered: false }

    linkedin.profile_snapshots.create!(captured_at: Time.current, data: {
      "pages" => { "experience" => { "text" => file_fixture("linkedin/experience.txt").read } }
    })
    differences = NaverPeople::CrossCheck.new(naver).linkedin_mismatches
    assert_includes differences, { topic: "현재 직함", linkedin: "한빛랩 · CTO", naver: "한빛랩 · 대표", note: "직함 다름" }
  end
end
