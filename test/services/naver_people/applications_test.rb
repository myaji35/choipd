require "test_helper"

class NaverPeople::ApplicationsTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 11, 24)

  test "reads a direct array and ignores non-hash entries" do
    raw = { "id" => 42, "itemName" => "직업", "applyDate" => "2026-11-20", "statusName" => "검토 중" }
    applications = NaverPeople::Applications.new({ "applications" => { "ING" => [ raw, nil ] } })

    assert_equal [ { id: 42, item: "직업", applied_on: "2026-11-20", status: "검토 중", rejected: false, reject_reason: nil, raw: raw } ], applications.in_progress
    assert_empty applications.completed
  end

  test "reads first array in a paginated result and extracts rejection reason" do
    raw = { "applyId" => "a1", "fieldName" => "소속", "regDate" => "2026-11-20", "resultStatus" => "REJECTED", "rejectMsg" => "증빙 자료 필요" }
    applications = NaverPeople::Applications.new({ "applications" => {
      "END" => { "content" => [ raw ], "items" => [] }
    } })

    assert_equal [ { id: "a1", item: "소속", applied_on: "2026-11-20", status: "REJECTED", rejected: true, reject_reason: "증빙 자료 필요", raw: raw } ], applications.completed
  end

  test "uses the first available array and reports errors by status" do
    raw = { "seq" => 0, "title" => "경력", "requestDate" => "2026-11-20", "state" => "반려 처리", "comment" => "기간 확인 필요" }
    applications = NaverPeople::Applications.new({ "applications" => {
      "ING" => { "error" => "HTTP 503" },
      "END" => { "content" => {}, "list" => nil, "resultList" => [ raw ] }
    } })

    assert_empty applications.in_progress
    assert_equal({ "ING" => "HTTP 503" }, applications.errors)
    assert_equal [ { id: 0, item: "경력", applied_on: "2026-11-20", status: "반려 처리", rejected: true, reject_reason: "기간 확인 필요", raw: raw } ], applications.completed
  end

  test "detects new, status changed, and finished applications" do
    profile = { "itemName" => "프로필 사진", "applyDate" => "2026-11-20", "status" => "접수" }
    job = { "id" => 42, "itemName" => "직업", "status" => "접수" }
    older = { "applications" => { "ING" => [ profile, job ], "END" => [] } }
    applications = NaverPeople::Applications.new({ "applications" => {
      "ING" => [ profile.merge("status" => "검토"), { "id" => 43, "itemName" => "경력", "status" => "접수" } ],
      "END" => [ job.merge("id" => "42", "status" => "승인") ]
    } })

    assert_equal [
      { kind: "status_changed", item: "프로필 사진", before: "접수", after: "검토" },
      { kind: "new", item: "경력", before: nil, after: "접수" },
      { kind: "finished", item: "직업", before: "접수", after: "승인" }
    ], applications.changes_from(older)
  end

  test "can compare completed statuses when the in-progress collection fails" do
    raw = { "requestId" => 7, "type" => "직업", "state" => "반려" }
    older = { "applications" => { "ING" => [ raw ], "END" => [ raw.merge("state" => "완료") ] } }
    applications = NaverPeople::Applications.new({ "applications" => {
      "ING" => { "error" => "요청 실패" }, "END" => [ raw ]
    } })

    assert_equal [ { kind: "status_changed", item: "직업", before: "완료", after: "반려" } ], applications.changes_from(older)
  end

  test "treats sentinel, missing, and invalid delegation dates as unlimited" do
    [ "2999-12-31", nil, "invalid" ].each do |value|
      assert_equal({ end_on: nil, days_left: nil, unlimited: true, expiring: false, expired: false }, delegation(value))
    end
  end

  test "warns on days zero through thirty and detects expiration" do
    [ [ -1, false, true ], [ 0, true, false ], [ 7, true, false ], [ 30, true, false ], [ 31, false, false ] ].each do |days, expiring, expired|
      date = TODAY + days
      assert_equal({ end_on: date, days_left: days, unlimited: false, expiring: expiring, expired: expired }, delegation(date.iso8601))
    end
  end

  private
    def delegation(value)
      NaverPeople::Applications.new({ "auth" => { "delegEndDate" => value } }, today: TODAY).delegation
    end
end
