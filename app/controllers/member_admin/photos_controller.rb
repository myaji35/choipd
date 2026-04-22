class MemberAdmin::PhotosController < MemberAdmin::BaseController
  skip_before_action :verify_authenticity_token, only: [ :create, :destroy, :update ]
  before_action :set_photo, only: [ :destroy, :update ]

  def create
    files = extract_files
    if files.empty?
      return render json: { success: false, error: "NO_FILE", message: "이미지 파일을 선택해주세요." }, status: :unprocessable_entity
    end

    created = []
    errors  = []

    files.each do |uploaded|
      ct = uploaded.content_type.to_s
      is_video = MemberPhoto::VIDEO_TYPES.include?(ct)
      limit = is_video ? MemberPhoto::VIDEO_MAX_BYTES : MemberPhoto::IMAGE_MAX_BYTES

      unless MemberPhoto::ALLOWED_TYPES.include?(ct)
        errors << { filename: uploaded.original_filename, message: "지원하지 않는 형식: #{ct}" }
        next
      end

      if uploaded.size > limit
        kind = is_video ? "영상" : "이미지"
        mb   = (limit / 1024.0 / 1024.0).round
        errors << {
          filename: uploaded.original_filename,
          message: "#{kind} #{(uploaded.size / 1024.0 / 1024.0).round(1)}MB — #{mb}MB를 초과합니다",
        }
        next
      end

      photo = @member.member_photos.new(
        category: (params[:category].presence || "daily"),
        caption: params[:caption],
        file_size: uploaded.size,
      )
      photo.image.attach(uploaded)

      if photo.save
        created << serialize(photo)
      else
        errors << { filename: uploaded.original_filename, message: photo.errors.full_messages.join(", ") }
      end
    end

    if created.empty? && errors.any?
      render json: { success: false, errors: errors, message: errors.first[:message] }, status: :unprocessable_entity
    else
      render json: { success: true, photos: created, errors: errors }, status: :created
    end
  end

  def destroy
    @photo.destroy
    render json: { success: true, id: @photo.id }
  end

  def update
    allowed = params.permit(:caption, :category, :sort_order)
    if @photo.update(allowed)
      render json: { success: true, photo: serialize(@photo) }
    else
      render json: { success: false, errors: @photo.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_photo
    @photo = @member.member_photos.find(params[:id])
  end

  def extract_files
    f = params[:files] || params[:file] || params[:image]
    Array(f).compact.reject { |u| !u.respond_to?(:original_filename) }
  end

  def serialize(photo)
    {
      id: photo.id,
      caption: photo.caption,
      category: photo.category,
      filename: photo.image.attached? ? photo.image.filename.to_s : nil,
      content_type: photo.image.attached? ? photo.image.content_type : nil,
      is_video: photo.video?,
      thumbnail_url: photo.thumbnail_url,
      display_url: photo.display_url,
      file_size: photo.file_size,
      uploaded_at: photo.uploaded_at&.iso8601,
    }
  end
end
