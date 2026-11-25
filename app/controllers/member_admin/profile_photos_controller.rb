class MemberAdmin::ProfilePhotosController < MemberAdmin::BaseController
  def update
    photo = if params.key?(:photo_id)
      @member.member_photos.find_by(id: params[:photo_id])
    else
      return reject_photo("이미지 파일을 선택해 주세요.") unless params[:image].is_a?(ActionDispatch::Http::UploadedFile)

      uploaded_photo(params[:image])
    end

    return reject_photo("선택한 사진을 사용할 수 없어요.") unless photo
    return reject_photo("프로필 사진은 지원되는 이미지 형식으로 올려 주세요.") unless photo.image?

    MemberPhoto.transaction do
      photo.save! if photo.new_record?
      @member.update!(profile_image: rails_blob_path(photo.image, only_path: true))
    end

    destination = if params[:from] == "checklist"
      slug_admin_dashboard_path(slug: @member.slug)
    else
      profile_photo_editor_path
    end
    redirect_to destination, notice: "프로필 사진을 바꿨어요.", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    message = if error.record.is_a?(MemberPhoto)
      error.record.errors[:image].join(" · ").presence
    end
    reject_photo(message || "프로필 사진을 저장하지 못했어요. 다시 시도해 주세요.")
  end

  private

  def uploaded_photo(upload)
    @member.member_photos.new(category: "people", file_size: upload.size, image: upload)
  end

  def reject_photo(message)
    flash[:profile_photo_error] = message
    redirect_to profile_photo_editor_path, status: :see_other
  end

  def profile_photo_editor_path
    context = params[:from] == "checklist" ? { from: "checklist", task: "profile-photo" } : {}
    slug_admin_editor_path(slug: @member.slug, step: 2, anchor: "profile-photo", **context)
  end
end
