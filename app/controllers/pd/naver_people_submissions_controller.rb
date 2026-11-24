class Pd::NaverPeopleSubmissionsController < Pd::BaseController
  before_action :set_naver_account
  before_action :set_submission, only: [ :mark_submitted, :cancel ]

  def create
    submission = NaverPeople::SubmissionPreparer.new.call(@account)
    case submission.status
    when "filled"
      redirect_to target_path, status: :see_other,
        notice: "ego 작업 공간 ##{submission.ego_space_id}에 입력해 두었습니다. 화면을 확인한 뒤 '다음'→신청을 직접 눌러 주세요."
    when "cancelled"
      redirect_to target_path, status: :see_other, alert: "입력 요청이 취소되었습니다."
    else
      redirect_to target_path, status: :see_other, alert: submission.result_message
    end
  rescue NaverPeople::SubmissionPreparer::Error => e
    redirect_to target_path, status: :see_other, alert: e.message
  end

  def mark_submitted
    transition([ "filled" ], "submitted", :submitted_at, "제출 기록을 저장했습니다.")
  end

  def cancel
    transition(NaverPeopleSubmission::CANCELLABLE_STATUSES, "cancelled", :cancelled_at, "입력 기록을 취소했습니다.")
  end

  private

  def set_naver_account
    @account = ProfileAccount.find(params[:profile_account_id])
    return if @account.platform == "naver_people"

    redirect_to pd_profile_account_path(@account), status: :see_other, alert: "네이버 인물정보 계정에서만 수정 신청을 입력할 수 있습니다."
  end

  def set_submission
    @submission = @account.naver_people_submissions.find_by(id: params[:id])
    head :not_found unless @submission
  end

  def transition(from, status, timestamp, message)
    changed = @submission.with_lock do
      @submission.update!(status: status, timestamp => Time.current) if from.include?(@submission.status)
    end
    if changed
      redirect_to target_path, status: :see_other, notice: message
    else
      redirect_to target_path, status: :see_other, alert: "현재 상태에서는 이 작업을 할 수 없습니다."
    end
  end

  def target_path
    pd_profile_account_naver_target_path(@account, anchor: "naver-submission")
  end
end
