require "test_helper"

class Linkedin::NaverComparisonTest < ActiveSupport::TestCase
  test "requires at least one collected comparison section even when it is empty" do
    naver = NaverPeople::Presenter.new({})
    refute Linkedin::NaverComparison.new({ basics: {}, skills: [] }, naver).comparable?

    %i[experiences education certifications].each do |section|
      assert Linkedin::NaverComparison.new({ section => [] }, naver).comparable?
    end
  end

  test "compares current offices and jobs, schools and licenses" do
    linkedin = {
      experiences: [
        { company: "Hanbit, Inc.", title: "CTO", current: true },
        { company: "(주)푸른 농장", title: "대표", current: true },
        { company: "예전 회사", title: "개발자", current: false }
      ],
      education: [ { school: "한국대학" }, { school: "가상대학" } ],
      certifications: [ { name: "데이터 분석 전문가" } ]
    }
    naver = NaverPeople::Presenter.new({ "people" => {
      "peopleOffice" => [
        { "name" => "HANBIT", "position" => "대표", "current" => "Y" },
        { "name" => "푸른농장 주식회사", "position" => "공동 대표", "current" => "Y" },
        { "name" => "다른 예전 회사", "position" => "개발자", "current" => "N" }
      ],
      "peopleJob" => [ { "nameTx" => "CTO" }, { "nameTx" => "작가" } ],
      "peopleSchool" => [ { "name" => "한국 대학교" } ],
      "peopleLicense" => [ { "name" => "프로젝트 관리 전문가" } ]
    } })

    assert_equal [
      { topic: "현재 직함", linkedin: "Hanbit, Inc. · CTO", naver: "HANBIT · 대표", note: "직함 다름" },
      { topic: "직업", linkedin: nil, naver: "작가", note: "LinkedIn에는 없음" },
      { topic: "학력", linkedin: "가상대학", naver: nil, note: "네이버에는 없음" },
      { topic: "자격증", linkedin: "데이터 분석 전문가", naver: nil, note: "네이버에는 없음" },
      { topic: "자격증", linkedin: nil, naver: "프로젝트 관리 전문가", note: "LinkedIn에는 없음" }
    ], Linkedin::NaverComparison.new(linkedin, naver).mismatches
    assert_empty Linkedin::NaverComparison.new({}, naver).mismatches
  end
end
