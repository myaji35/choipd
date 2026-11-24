require "test_helper"

class Linkedin::ProfileParserTest < ActiveSupport::TestCase
  setup do
    @pages = %w[profile experience education skills certifications].index_with do |name|
      { "text" => file_fixture("linkedin/#{name}.txt").read }
    end
  end

  test "parses the captured profile and detail pages" do
    profile = Linkedin::ProfileParser.new(@pages).to_h
    assert_equal "홍길동", profile[:basics][:name]
    assert_equal "한빛상사 대표 | 데이터 분석 컨설턴트", profile[:basics][:headline]
    assert_equal "대한민국 서울특별시", profile[:basics][:location]
    assert_equal "데이터로 일하는 작은 회사를 돕습니다.\n보고서 자동화와 분석 교육을 합니다.", profile[:basics][:about]
    assert_operator profile[:experiences].size, :>=, 4
    assert_equal({ title: "CTO", company: "한빛랩", employment_type: "정규직", period: "2026년 7월 - 현재",
                   current: true, location: nil, description: "" }, profile[:experiences].first)
    assert_equal "강원도 춘천시", profile[:experiences][1][:location]
    assert_empty profile[:experiences][1][:description]
    assert_equal "한국대학", profile[:education].first[:school]
    assert_equal "Computer Engineering", profile[:education].first[:major]
    assert_equal "소프트웨어 개발, 컴퓨터공학", profile[:education].first[:skills_text]
    %w[파이톤 데이터\ 분석 Project\ Management].each { |skill| assert_includes profile[:skills], skill }
    [ "Hanbit, Inc. 대표 / Founder", "한국대학" ].each { |context| refute_includes profile[:skills], context }
    assert_empty profile[:certifications]
  end

  test "parses both certificates with an optional ID line" do
    pages = { "certifications" => { "text" => file_fixture("linkedin/certifications_filled.txt").read } }
    certifications = Linkedin::ProfileParser.new(pages).to_h[:certifications]
    assert_equal [
      { name: "데이터 분석 전문가", issuer: "가상 데이터 협회", issued: "2024년 3월" },
      { name: "프로젝트 관리 전문가", issuer: "가상 프로젝트 협회", issued: "2023년 6월" }
    ], certifications
  end

  test "distinguishes unavailable pages from collected empty pages" do
    profile = Linkedin::ProfileParser.new({ "profile" => { "error" => "timeout" }, "skills" => { "text" => "" } }).to_h
    assert_nil profile[:basics]
    assert_nil profile[:experiences]
    assert_empty profile[:skills]
  end

  test "parses education without a major and an introduction without a show all line" do
    profile = Linkedin::ProfileParser.new({
      "education" => { "text" => "학력\n한국대학\n1987년 - 1991년" },
      "profile" => { "text" => "홍길동\n헤드라인\n소개\n소개 내용\n대표 보유기술" }
    }).to_h
    assert_equal "한국대학", profile[:education].first[:school]
    assert_nil profile[:education].first[:major]
    assert_equal "소개 내용", profile[:basics][:about]
  end

  test "keeps consecutive entries with a single heading line between periods separate" do
    profile = Linkedin::ProfileParser.new({
      "education" => { "text" => "학력\n한국대학\n1987년 - 1991년\n가상대학\n1992년 - 1994년" },
      "experience" => { "text" => "경력\n개발자\n한빛랩\n2024년 - 2025년\n대표\n2025년 - 현재" }
    }).to_h

    assert_equal [ [ "한국대학", nil ], [ "가상대학", nil ] ], profile[:education].map { |entry| entry.values_at(:school, :major) }
    assert_equal [ [ "개발자", "한빛랩", "" ], [ "대표", nil, "" ] ],
      profile[:experiences].map { |entry| entry.values_at(:title, :company, :description) }
  end

  test "recognizes short locations only in the first two detail lines" do
    sentence = "고객이 원하는 시스템을 구축하도록 도 왔습니다"
    long_line = "경기도 #{"설명 " * 20}입니다"
    profile = Linkedin::ProfileParser.new({
      "experience" => { "text" => "경력\n대표\n한빛랩\n2025년 - 현재\n#{sentence}\n세종특별자치시 · 대면근무\n경기도\n개발자\n가상회사\n2020년 - 2024년\n#{long_line}" }
    }).to_h

    first, second = profile[:experiences]
    assert_equal "세종특별자치시 · 대면근무", first[:location]
    assert_equal "#{sentence}\n경기도", first[:description]
    assert_nil second[:location]
    assert_equal long_line, second[:description]
  end

  test "removes detail lines made up entirely of collected skills" do
    pages = {
      "experience" => { "text" => "경력\n대표\n한빛랩\n2025년 - 현재\n소프트웨어 개발\n파이톤, SQL\nSQL, 교육을 진행했습니다" },
      "skills" => { "text" => "보유기술\n소프트웨어 개발\n파이톤\nSQL" }
    }

    assert_equal "SQL, 교육을 진행했습니다", Linkedin::ProfileParser.new(pages).to_h[:experiences].sole[:description]
    assert_equal "소프트웨어 개발\n파이톤, SQL\nSQL, 교육을 진행했습니다",
      Linkedin::ProfileParser.new(pages.except("skills")).to_h[:experiences].sole[:description]
  end

  test "stops an introduction at a standalone section heading" do
    %w[활동 경력 학력 보유기술 자격증/수료증 추천 관심분야 스페셜 언어 봉사활동 프로젝트 출판물 수상\ 경력].each do |heading|
      pages = { "profile" => { "text" => "홍길동\n헤드라인\n소개\n#{heading} 소식을 전합니다.\n#{heading}\n다음 섹션 내용" } }
      assert_equal "#{heading} 소식을 전합니다.", Linkedin::ProfileParser.new(pages).to_h[:basics][:about]
    end
  end
end
