require "test_helper"

class NaverPeopleSubmissionTest < ActiveSupport::TestCase
  test "defaults to preparing with empty JSON arrays and persists lists" do
    account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물")
    submission = account.naver_people_submissions.create!
    assert_equal "preparing", submission.status
    assert_equal [ [], [], [] ], [ submission.items, submission.filled_items, submission.manual_items ]

    item = { "label" => "영문명", "after" => "Example Name" }
    submission.update!(items: [ item ], filled_items: [ item ], manual_items: [ { "tab" => "기본정보" } ])
    submission.reload
    assert_equal [ item ], submission.items
    assert_equal [ item ], submission.filled_items
    assert_equal [ { "tab" => "기본정보" } ], submission.manual_items
    refute submission.update(status: "unknown")

    assert_difference "NaverPeopleSubmission.count", -1 do
      account.destroy!
    end
  end
end
