require "test_helper"

class NaverPeople::SubmissionPreparerTest < ActiveSupport::TestCase
  setup do
    @account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물", tenant_id: 2)
    @account.profile_snapshots.create!(captured_at: Time.current, data: { "people" => {
      "ename" => "Old Name",
      "peopleJob" => [ { "nameTx" => "기업인" } ],
      "peopleOffice" => [ { "name" => "한빛랩", "position" => "팀장" } ],
      "peopleSite" => [ { "url" => "https://old.example.test" } ]
    } })
    @target = @account.create_naver_people_target!(tenant_id: 2, values: {
      "ename" => "New Name", "jobs" => "작가", "offices" => "한빛랩 | 대표",
      "careers" => "2026~현재 | 한빛랩", "schools" => "한빛대", "prizes" => "한빛상",
      "licenses" => "한빛자격", "sites" => %w[https://new.example.test http://fallback.example.test]
    })
  end

  test "rejects unapproved, stale and empty drafts before calling ego" do
    preparer = build_preparer { flunk "ego must not run" }
    assert_no_difference "NaverPeopleSubmission.count" do
      error = assert_raises(NaverPeople::SubmissionPreparer::Error) { preparer.call(@account) }
      assert_equal "승인된 최신 초안이 없습니다.", error.message
      approve(digest: "old")
      error = assert_raises(NaverPeople::SubmissionPreparer::Error) { preparer.call(@account) }
      assert_equal "다시 승인 필요", error.message
      @target.update!(values: {})
      approve
      error = assert_raises(NaverPeople::SubmissionPreparer::Error) { preparer.call(@account) }
      assert_equal "바꿀 항목이 없습니다.", error.message
    end
  end

  test "records verified automatic values and orders the remaining draft items with manual tabs" do
    approve
    preparer = build_preparer do |account:, job:, ename:, sites:|
      assert_equal @account, account
      assert_equal "기업인", job
      assert_equal "New Name", ename
      assert_equal %w[http://fallback.example.test https://new.example.test], sites
      assert_equal "preparing", account.naver_people_submissions.sole.status
      { "ok" => true, "space_id" => 42, "filled" => [
        { "field" => "ename", "value" => ename }, { "field" => "sites", "value" => sites.last }
      ], "failed" => [ { "value" => sites.first, "reason" => "주소 확인 실패" } ] }
    end

    record = preparer.call(@account).reload
    assert_equal [ "filled", "42", 2, @target.approved_draft_digest ],
      [ record.status, record.ego_space_id, record.tenant_id, record.target_digest ]
    assert record.prepared_at
    assert_equal %w[ename sites], record.filled_items.pluck("field")
    assert_equal [
      [ "기본정보", "직업", "remove" ], [ "기본정보", "직업", "add" ],
      [ "소속/경력", "소속", "change" ], [ "소속/경력", "경력", "add" ],
      [ "학력/수상/자격증", "학력", "add" ], [ "학력/수상/자격증", "수상", "add" ],
      [ "학력/수상/자격증", "자격증", "add" ], [ "기본정보", "사이트", "remove" ],
      [ "기본정보", "사이트", "add" ]
    ], record.manual_items.map { |item| item.values_at("tab", "label", "action") }
    assert_equal [ "한빛랩 | 팀장", "한빛랩 | 대표" ], record.manual_items[2].values_at("before", "after")
    assert_equal "주소 확인 실패", record.manual_items.last["reason"]
  end

  test "records the failure reason" do
    approve
    preparer = build_preparer { { "ok" => false, "reason" => "로그인이 필요합니다." } }

    record = preparer.call(@account).reload
    assert_equal "failed", record.status
    assert_equal "로그인이 필요합니다.", record.result_message
    assert_nil record.prepared_at
  end

  test "marks the reservation failed when the filler raises" do
    approve
    preparer = build_preparer { raise IOError, "ego 응답을 읽을 수 없습니다." }

    record = preparer.call(@account).reload
    assert_equal "failed", record.status
    assert_equal "ego 응답을 읽을 수 없습니다.", record.result_message
  end

  test "marks the reservation failed when applying the filler result raises" do
    approve
    preparer = build_preparer { { "ok" => true, "space_id" => 42, "filled" => [ nil ] } }

    record = preparer.call(@account).reload
    assert_equal "failed", record.status
    assert_match(/values_at/, record.result_message)
  end

  test "rejects the result when a changed draft is approved during filling" do
    approve
    preparer = build_preparer do
      @target.update!(values: @target.values.merge("ename" => "Changed Name"))
      approve
      { "ok" => true, "space_id" => 42 }
    end

    record = preparer.call(@account).reload
    assert_equal "failed", record.status
    assert_equal "42", record.ego_space_id
    assert_equal "입력 중 목표 프로필이 바뀌었습니다. ego 작업 공간 #42를 확인 후 닫고 다시 입력하세요.", record.result_message
    assert_nil record.prepared_at
  end

  test "uses the first column of the first current Naver job ahead of the account headline" do
    @account.update!(headline: "기자")
    @account.profile_snapshots.create!(captured_at: Time.current, data: { "people" => {
      "peopleJob" => [ { "nameTx" => "기업인 | 설명" }, { "nameTx" => "작가" } ]
    } })
    approve
    preparer = build_preparer do |job:, **|
      assert_equal "기업인", job
      { "ok" => true, "space_id" => 42 }
    end

    assert_equal "filled", preparer.call(@account).status
  end

  test "returns the existing filled record for the digest without calling ego" do
    approve
    record = @account.naver_people_submissions.create!(status: "filled", target_digest: @target.approved_draft_digest)
    preparer = build_preparer { flunk "ego must not run twice" }

    assert_no_difference "NaverPeopleSubmission.count" do
      assert_equal record, preparer.call(@account)
    end
  end

  test "blocks overlapping preparations for the same ego space" do
    approve
    preparer = build_preparer { flunk "ego must not run concurrently" }
    @account.naver_people_submissions.create!(status: "preparing", target_digest: "another-digest")

    error = assert_raises(NaverPeople::SubmissionPreparer::Error) { preparer.call(@account) }
    assert_match(/입력 중/, error.message)
  end

  private

  def approve(digest: nil)
    current = NaverPeople::TargetSources.new(@account).values_for("naver")
    digest ||= NaverPeople::TargetDiff.new(current, @target.values).digest
    @target.update!(status: "approved", approved_draft_digest: digest, approved_at: Time.current)
  end

  def build_preparer(&execute)
    filler = Object.new
    filler.define_singleton_method(:call) { |**payload| execute.call(**payload) }
    NaverPeople::SubmissionPreparer.new(filler: filler)
  end
end
