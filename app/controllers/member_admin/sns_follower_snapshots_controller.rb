class MemberAdmin::SnsFollowerSnapshotsController < MemberAdmin::BaseController
  def create
    sns_account = @member.sns_accounts.find(params[:sns_account_id])
    snapshot = sns_account.sns_follower_snapshots.new(
      follower_count: follower_snapshot_params[:follower_count],
      source: "manual",
      captured_at: Time.current
    )

    if snapshot.save
      redirect_to slug_admin_sns_accounts_path(slug: @member.slug), notice: "추종자 수를 기록했습니다."
    else
      redirect_to slug_admin_sns_accounts_path(slug: @member.slug), alert: snapshot.errors.full_messages.join(", ")
    end
  end

  private

  def follower_snapshot_params
    params.require(:sns_follower_snapshot).permit(:follower_count)
  end
end
