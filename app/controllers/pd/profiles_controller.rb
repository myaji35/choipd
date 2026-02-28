class Pd::ProfilesController < Pd::BaseController
  def edit
    @admin_user = current_admin_user
  end

  def update
    @admin_user = current_admin_user
    if @admin_user.update(profile_params)
      redirect_to edit_pd_profile_path, notice: "프로필이 업데이트되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:admin_user).permit(:email)
  end
end
