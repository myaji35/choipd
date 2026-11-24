require "test_helper"

class Linkedin::ProfilePresenterTest < ActiveSupport::TestCase
  test "shows profile sections and scores only collected checks" do
    presenter = Linkedin::ProfilePresenter.new({
      basics: { name: "홍길동", headline: "대표", about: "가" * 100 },
      experiences: [ { title: "대표", company: "한빛랩", current: true, description: "데이터 분석" } ],
      skills: %w[파이톤 SQL 교육 기획 분석],
      certifications: []
    })

    sections = presenter.sections.index_by { |section| section[:key] }
    assert_includes sections[:basics][:rows], { label: "이름", value: "홍길동" }
    assert_equal "가" * 100, sections[:about][:text]
    assert_equal [ "대표 · 한빛랩 · 데이터 분석" ], sections[:experiences][:items]
    checks = presenter.completeness.index_by { |check| check[:key] }
    assert_nil checks[:education][:filled]
    assert_equal "확인 못 함", checks[:education][:hint]
    assert_equal false, checks[:certifications][:filled]
    assert_equal 75, presenter.completeness_score
    assert_nil Linkedin::ProfilePresenter.new({}).completeness_score
  end
end
