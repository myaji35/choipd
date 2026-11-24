require "test_helper"

class Linkedin::ProfileDifferTest < ActiveSupport::TestCase
  test "finds experience addition, headline change and skill removal" do
    older = { basics: { headline: "개발자" }, experiences: [], skills: %w[파이톤 SQL], education: nil }
    newer = { basics: { headline: "대표" }, experiences: [ { company: "한빛랩", title: "대표" } ],
              skills: %w[파이톤], education: [ { school: "한국대학" } ] }

    assert_equal [
      { section: "기본정보", kind: "changed", label: "헤드라인", before: "개발자", after: "대표" },
      { section: "경력", kind: "added", label: "한빛랩 · 대표", before: nil, after: "대표 · 한빛랩" },
      { section: "기술", kind: "removed", label: "SQL", before: "SQL", after: nil }
    ], Linkedin::ProfileDiffer.new(older, newer).changes
  end

  test "tracks descriptions and periods for the same experience" do
    entry = { company: "한빛랩", title: "대표", period: "2024년 - 현재", description: "데이터 분석" }
    older = { experiences: [ entry ] }
    newer = { experiences: [ entry.merge(period: "2024년 - 2025년", description: "분석 교육") ] }

    change = Linkedin::ProfileDiffer.new(older, newer).changes.sole
    assert_equal "changed", change[:kind]
    assert_includes change[:before], "2024년 - 현재 · 데이터 분석"
    assert_includes change[:after], "2024년 - 2025년 · 분석 교육"
  end

  test "matches duplicate identities by occurrence in each section" do
    experience = { company: "한빛랩", title: "대표", employment_type: "정규직" }
    education = { school: "한국대학", major: "컴퓨터공학" }
    certification = { name: "데이터 분석 전문가", issuer: "가상 데이터 협회" }
    older = { experiences: [ experience, experience ], education: [ education, education ],
              certifications: [ certification, certification ] }
    newer = { experiences: [ experience.merge(employment_type: "시간제"), experience ],
              education: [ education.merge(major: "통계학"), education ],
              certifications: [ certification.merge(issuer: "가상 분석 협회"), certification ] }

    changes = Linkedin::ProfileDiffer.new(older, newer).changes
    assert_equal [ [ "경력", "changed" ], [ "학력", "changed" ], [ "자격증", "changed" ] ],
      changes.map { |change| change.values_at(:section, :kind) }
    assert_includes changes[0][:after], "시간제"
    assert_includes changes[1][:after], "통계학"
    assert_includes changes[2][:after], "가상 분석 협회"
  end

  test "tracks each location, education period and certificate issue date change on its own" do
    older = { experiences: [ { company: "한빛랩", title: "대표" } ],
              education: [ { school: "한국대학" } ], certifications: [ { name: "데이터 분석 전문가" } ] }
    newer = { experiences: [ older[:experiences].sole.merge(location: "서울특별시") ],
              education: [ older[:education].sole.merge(period: "1987년 - 1991년") ],
              certifications: [ older[:certifications].sole.merge(issued: "2024년 3월") ] }

    assert_equal %w[changed changed changed], Linkedin::ProfileDiffer.new(older, newer).changes.pluck(:kind)
    assert_equal %w[removed removed removed],
      Linkedin::ProfileDiffer.new(older.transform_values { |entries| entries * 2 }, older).changes.pluck(:kind)
  end
end
