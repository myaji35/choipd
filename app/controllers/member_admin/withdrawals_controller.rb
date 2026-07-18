class MemberAdmin::WithdrawalsController < MemberAdmin::BaseController
  def show
    @counts = {
      documents: @member.member_documents.count,
      photos: @member.member_photos.count,
      services: @member.member_services.count
    }
  end

  def destroy
    if params[:confirm_name].to_s.strip != @member.name.to_s.strip
      redirect_to slug_admin_withdraw_path(slug: @member.slug), alert: "확인을 위해 이름을 정확히 입력해주세요." and return
    end

    if MemberWithdrawalService.new(@member).call
      reset_session
      redirect_to root_path, notice: "탈퇴가 완료되었습니다. 그동안 이용해 주셔서 감사합니다."
    else
      redirect_to slug_admin_withdraw_path(slug: @member.slug), alert: "탈퇴 처리 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요."
    end
  end
end
