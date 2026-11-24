require "test_helper"

class NaverPeople::TargetDiffTest < ActiveSupport::TestCase
  test "compares normalized lines and matches edits by the first column" do
    current = {
      "ename" => "Before", "jobs" => [ "CEO", "작가" ], "offices" => [ "Hanbit | CTO" ],
      "careers" => [ "2024.08~현재 | 누리팜 직원" ], "schools" => [ "한국대학 | 국문과" ],
      "sites" => [ "https://keep.example" ]
    }
    target = {
      "ename" => "After", "jobs" => [ " ceo  ", "기업인" ], "offices" => [ "hanbit| 대표" ],
      "careers" => [ "2024.08~현재 | 누리팜 대표" ], "schools" => [ "한국대학 | 데이터과" ]
    }
    items = NaverPeople::TargetDiff.new(current, target).items
    assert_equal [
      [ "ename", "change" ], [ "jobs", "remove" ], [ "jobs", "add" ], [ "offices", "change" ],
      [ "careers", "change" ], [ "schools", "change" ]
    ], items.map { |item| item.values_at(:field, :action) }
    assert_equal [ "작가", nil, [] ], items[1].values_at(:before, :after, :evidence)
  end

  test "deduplicates checklist documents and keeps a stable digest across ordering" do
    first = NaverPeople::TargetDiff.new({}, { "jobs" => %w[기업인 작가] })
    reordered = NaverPeople::TargetDiff.new({}, { "jobs" => %w[작가 기업인] })
    assert_equal [ { document: "재직증명서 또는 사업자등록증", for: [ "직업" ] } ], first.checklist
    assert_match(/\A[0-9a-f]{16}\z/, first.digest)
    assert_equal first.digest, reordered.digest
    refute_equal first.digest, NaverPeople::TargetDiff.new({}, { "jobs" => [ "작가" ] }).digest
  end

  test "supports scalar addition and explicit removal" do
    assert_equal "add", NaverPeople::TargetDiff.new({}, { "ename" => "Test" }).items.sole[:action]
    assert_equal "remove", NaverPeople::TargetDiff.new({ "ename" => "Test" }, { "ename" => "" }).items.sole[:action]
  end
end
