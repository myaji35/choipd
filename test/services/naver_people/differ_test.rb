require "test_helper"

class NaverPeople::DifferTest < ActiveSupport::TestCase
  test "detects scalar and career changes while ignoring volatile fields" do
    old = { "people" => { "name" => "가상 이름", "peopleCareer" => [ { "id" => 1, "comment" => "이전" }, { "id" => 2, "comment" => "삭제" }, { "id" => 4, "comment" => "유지", "someImg" => "old" } ] } }
    current = { "people" => { "name" => "새 이름", "peopleCareer" => [ { "id" => 1, "comment" => "이후" }, { "id" => 3, "comment" => "추가" }, { "id" => 4, "comment" => "유지", "someImg" => "new" } ] } }
    changes = NaverPeople::Differ.new(old, current).changes
    assert_equal 4, changes.size
    assert changes.any? { |c| c[:label] == "이름" && c[:kind] == "changed" }
    %w[added removed changed].each { |kind| assert changes.any? { |c| c[:section] == "경력" && c[:kind] == kind } }
  end
end
