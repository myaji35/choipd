require "test_helper"

class NaverPeople::PresenterTest < ActiveSupport::TestCase
  test "formats sections and completeness" do
    presenter = NaverPeople::Presenter.new({ "auth" => { "relKind" => "ME", "status" => "ACCEPT", "delegEndDate" => "2999-12-31" }, "people" => { "name" => "가상 이름", "birthYear" => "1990", "birthMonth" => "2", "birthDay" => "3", "sex" => "F", "ename" => "Fake", "peopleCareer" => [ { "startDate" => "202401", "current" => "Y", "comment" => "가상 대표" } ] } })
    assert_includes presenter.sections.first[:rows], { label: "출생", value: "1990-02-03" }
    assert_includes presenter.sections.find { |s| s[:title] == "경력" }[:items], "2024.01 ~ 현재 · 가상 대표"
    assert_includes presenter.sections.last[:rows], { label: "위임 기간", value: "무기한" }
    assert_equal 20, presenter.completeness_score
  end

  test "handles missing and unexpected types" do
    [ {}, nil, { "people" => [], "auth" => "invalid" }, { "people" => { "peopleCareer" => [ nil, "bad", {} ], "name" => [], "blog" => {} } } ].each do |data|
      presenter = NaverPeople::Presenter.new(data)
      assert presenter.sections.any?
      assert_equal 10, presenter.completeness.size
    end
  end
end
