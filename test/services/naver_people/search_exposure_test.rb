require "test_helper"

class NaverPeople::SearchExposureTest < ActiveSupport::TestCase
  setup do
    @data = {
      "dss" => 42140857,
      "people" => {
        "name" => "강승식",
        "peopleJob" => [ { "nameTx" => "기업인", "annual" => 9 } ],
        "peopleOffice" => [ { "name" => "주식회사 가가호호" }, { "name" => "누리팜" } ],
        "peopleSchool" => [ { "name" => "가천대학교", "major" => "전자계산과", "degree" => "학사" } ],
        "peopleCareer" => [ { "startDate" => "202408", "current" => "Y", "comment" => "누리팜 대표" } ]
      },
      "search" => {
        "checked_at" => "2026-11-24T12:00:00Z",
        "results" => [
          {
            "query" => "강승식 가가호호",
            "main" => { "os" => "42140857", "name" => "강승식", "aliases" => [ "강승식, Kang Seung Sig" ], "job" => "기업인", "profile_text" => <<~BOX },
              출생
              1968.06.13.
              소속
              주식회사 가가호호(대표이사), 누리팜(대표)
              학력
              가천대학교 전자계산과 전문학사
              경력
              2024.08.~ 누리팜 대표
              활동
              관련활동
              본인 또는 대리인이 직접 관리하는 정보입니다.
              본인참여 2026.09.23.
            BOX
            "same_name" => [ { "os" => "459417", "name" => "강승식", "details" => [ "교육자", "1964" ] } ]
          },
          {
            "query" => "강승식",
            "main" => { "os" => "4058035", "name" => "강승식", "job" => "가수" },
            "same_name" => [ { "os" => "459417" }, { "os" => "42140857", "details" => [ "기업인", "1968" ] } ]
          },
          { "query" => "강승식 다른 회사", "main" => nil, "same_name" => [ { "os" => "2840091" } ] },
          { "query" => "강승식 기업인", "error" => "시간 초과" }
        ]
      }
    }
    @exposure = NaverPeople::SearchExposure.new(@data)
  end

  test "classifies results using the public os number and generates encoded links" do
    assert @exposure.collected?
    assert_equal "2026-11-24T12:00:00Z", @exposure.checked_at
    main, same_name, absent, error = @exposure.results
    assert_equal %w[main same_name absent error], [ main, same_name, absent, error ].pluck(:status)
    assert_equal [ [ "강승식, Kang Seung Sig" ], "기업인" ], main.values_at(:main_aliases, :main_job)
    assert_equal [ "4058035", "강승식", "가수" ], same_name.values_at(:main_os, :main_name, :main_job)
    assert_empty same_name[:main_aliases]
    assert_equal "시간 초과", error[:error]
    assert_equal({ "where" => "nexearch", "query" => "강승식 가가호호" }, URI.decode_www_form(URI(main[:search_url]).query).to_h)
  end

  test "deduplicates namesakes and excludes the account os" do
    namesakes = @exposure.namesakes.index_by { |person| person[:os] }
    assert_equal %w[2840091 4058035 459417], namesakes.keys.sort
    assert_equal "교육자 · 1964", namesakes.fetch("459417")[:details]
    assert_equal "가수", namesakes.fetch("4058035")[:details]
    assert_includes namesakes.fetch("4058035")[:url], "pkid=1&os=4058035"
  end

  test "compares content under each box label with the participation profile" do
    rows = @exposure.box_comparison.index_by { |row| row[:label] }
    assert_equal [ true, true, true, false, true ], rows.values.pluck(:match)
    assert_equal "가천대학교 전자계산과 전문학사", rows.fetch("학력")[:search_value]
    assert_equal "가천대학교 전자계산과 학사", rows.fetch("학력")[:profile_value]
    assert_equal "2024.08.~ 누리팜 대표", rows.fetch("경력")[:search_value]
    @data["people"]["peopleOffice"] << { "name" => "미노출 회사" }
    assert_equal false, @exposure.box_comparison.find { |row| row[:label] == "소속" }[:match]
  end

  test "compares statuses for queries collected in both snapshots" do
    older = @data.deep_dup
    older["search"]["results"].first["main"] = nil
    older["search"]["results"].pop
    assert_equal [ { query: "강승식 가가호호", before: "absent", after: "main" } ], @exposure.changes_from(older)
    assert_empty @exposure.changes_from({ "people" => {} })
  end

  test "handles older snapshots and snapshots without a main box" do
    [ nil, {}, { "search" => [] } ].each do |data|
      legacy = NaverPeople::SearchExposure.new(data)
      refute legacy.collected?
      assert_empty legacy.results
      assert_empty legacy.namesakes
      assert_empty legacy.box_comparison
    end
    @data["search"]["results"].shift
    assert_empty @exposure.box_comparison
  end
end
