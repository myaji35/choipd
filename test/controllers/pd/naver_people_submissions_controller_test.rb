require "test_helper"

class Pd::NaverPeopleSubmissionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in AdminUser.create!(email: "naver-submission@example.test", password: "password123", role: "pd")
    @account = ProfileAccount.create!(platform: "naver_people", display_name: "가상 인물", headline: "작가")
    @target_path = pd_profile_account_naver_target_path(@account, anchor: "naver-submission")
    @create_path = pd_profile_account_naver_target_submissions_path(@account)
  end

  test "prepares an approved draft and displays the result and controls" do
    @account.create_naver_people_target!(values: { "ename" => "Example Name", "prizes" => "한빛상" })
    patch approve_pd_profile_account_naver_target_path(@account)
    get pd_profile_account_naver_target_path(@account)
    assert_select "#naver-submission form[data-turbo-confirm][action=?]", @create_path

    with_filler do |account:, job:, ename:, sites:|
      assert_equal [ @account, "작가", "Example Name", [] ], [ account, job, ename, sites ]
      { "ok" => true, "space_id" => 7, "filled" => [ { "field" => "ename", "value" => ename } ] }
    end

    assert_response :see_other
    assert_redirected_to @target_path
    assert_match(/ego 작업 공간 #7/, flash[:notice])
    follow_redirect!
    assert_select "#naver-submission strong", text: "입력 완료·대표님 제출 대기"
    assert_select "#naver-submission li", text: "영문명 · Example Name"
    assert_select "#naver-submission ol li", text: "학력/수상/자격증 → 수상 → 추가 → 한빛상"
    assert_select "#naver-submission button", text: "제출했음"
  end

  test "rejects create before approval" do
    assert_no_difference "NaverPeopleSubmission.count" do
      post @create_path
    end
    assert_redirected_to @target_path
    assert_equal "승인된 최신 초안이 없습니다.", flash[:alert]
  end

  test "marks only filled records as submitted" do
    submission = @account.naver_people_submissions.create!
    path = mark_submitted_pd_profile_account_naver_target_submission_path(@account, submission)
    patch path
    assert_equal "preparing", submission.reload.status
    assert flash[:alert]

    submission.update!(status: "filled")
    patch path
    assert_redirected_to @target_path
    assert_equal "submitted", submission.reload.status
    assert submission.submitted_at
  end

  test "rejects cancellation and hides the button while preparation is in progress" do
    submission = @account.naver_people_submissions.create!
    path = cancel_pd_profile_account_naver_target_submission_path(@account, submission)
    get pd_profile_account_naver_target_path(@account)
    assert_select "#naver-submission strong", text: "입력 중"
    assert_select "#naver-submission form[action=?]", path, count: 0

    patch path
    assert_redirected_to @target_path
    assert_equal "현재 상태에서는 이 작업을 할 수 없습니다.", flash[:alert]
    assert_equal "preparing", submission.reload.status
    assert_nil submission.cancelled_at
  end

  test "cancels filled and failed records but preserves submitted records" do
    %w[filled failed submitted].each do |status|
      submission = @account.naver_people_submissions.create!(status: status)
      patch cancel_pd_profile_account_naver_target_submission_path(@account, submission)
      assert_redirected_to @target_path
      if status == "submitted"
        assert_equal "submitted", submission.reload.status
        assert_nil submission.cancelled_at
      else
        assert_equal "cancelled", submission.reload.status
        assert submission.cancelled_at
      end
    end
  end

  test "rejects LinkedIn accounts" do
    linkedin = ProfileAccount.create!(platform: "linkedin", display_name: "LinkedIn 계정")
    assert_no_difference "NaverPeopleSubmission.count" do
      post pd_profile_account_naver_target_submissions_path(linkedin)
    end
    assert_redirected_to pd_profile_account_path(linkedin)
    assert_match(/네이버 인물정보 계정/, flash[:alert])
  end

  test "returns 404 for another account's submission" do
    other = ProfileAccount.create!(platform: "naver_people", display_name: "다른 인물")
    submission = other.naver_people_submissions.create!(status: "filled")
    patch mark_submitted_pd_profile_account_naver_target_submission_path(@account, submission)
    assert_response :not_found
    patch cancel_pd_profile_account_naver_target_submission_path(@account, submission)
    assert_response :not_found
    assert_equal "filled", submission.reload.status
  end

  private

  def with_filler(&execute)
    filler = Object.new
    filler.define_singleton_method(:call) { |**payload| execute.call(**payload) }
    original = EgoProfile::NaverSubmissionFiller.method(:new)
    EgoProfile::NaverSubmissionFiller.define_singleton_method(:new) { filler }
    post @create_path
  ensure
    EgoProfile::NaverSubmissionFiller.define_singleton_method(:new, original)
  end
end
