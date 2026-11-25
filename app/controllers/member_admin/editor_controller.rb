class MemberAdmin::EditorController < MemberAdmin::BaseController
  include MemberAdmin::ProfileChecklist

  # 4단계 에디터: 업로드 → 정보 확인 → 스타일 선택 → 발행.
  # GET  /<slug>/admin/editor?step=N
  # PATCH /<slug>/admin/editor/update_info   (Step 2 저장)
  # PATCH /<slug>/admin/editor/update_style  (Step 3 저장)
  # PATCH /<slug>/admin/editor/publish       (Step 4 발행)
  def show
    @step = (params[:step] || 1).to_i.clamp(1, 4)
    if @step == 2
      @profile_photo_choices = @member.member_photos.joins(image_attachment: :blob)
        .where(active_storage_blobs: { content_type: MemberPhoto::IMAGE_TYPES })
        .with_attached_image.order(uploaded_at: :desc, id: :desc).limit(8)
    end
    @documents = @member.member_documents.order(uploaded_at: :desc)
    @portfolio_count = @member.member_portfolio_items.count
    @services_count  = @member.member_services.count
    @photos_count    = @member.member_photos.count
    @skills          = @member.member_skills.includes(:skill).joins(:skill).order(weight: :desc).limit(12)
    @doc_count       = @documents.size
    @presets         = ThemePreset::THEME_PRESETS
    @layout_presets  = LayoutPreset::LAYOUT_PRESETS
    @checklist       = build_profile_checklist(from_checklist: false)
    @publish_missing = []
    @publish_missing << "자기소개 20자 이상" if @member.bio.to_s.length < 20
    @publish_missing << "직업" if @member.profession.blank?
    @publish_missing << "이메일" if @member.email.blank?
    @can_publish = @publish_missing.empty?
  end

  def update_info
    permitted = params.require(:member).permit(:bio, :profession, :region, :phone, :email, :kakao_channel, :career_note, :custom_profession)
    custom_profession = permitted.delete(:custom_profession).to_s.strip
    if permitted[:profession] == "custom" && custom_profession.present?
      permitted[:profession] = custom_profession
    end
    kakao_ch = permitted.delete(:kakao_channel)

    # social_links JSON 안에 kakao_channel 저장
    if kakao_ch.present?
      social = JSON.parse(@member.social_links || "{}") rescue {}
      social["kakao_channel"] = kakao_ch
      @member.social_links = social.to_json
    end

    if @member.update(permitted)
      redirect_to slug_admin_editor_path(slug: @member.slug, step: 3), notice: "내 정보를 저장했어요. 이제 스타일을 골라 주세요."
    else
      redirect_to action: :show, params: { slug: @member.slug, step: 2 }, alert: @member.errors.full_messages.join(" · ")
    end
  end

  def update_style
    key = params[:theme_preset].to_s
    preset = ThemePreset.find(key)
    if preset
      layout_key = params[:layout_preset].to_s
      layout = LayoutPreset.find(layout_key)
      attributes = { theme_preset: key }
      attributes[:layout_preset] = layout_key if layout
      @member.update!(attributes)

      notice = if layout
        "'#{preset[:name]}' 스타일과 '#{layout[:name]}' 구성으로 저장했어요. 이제 공개만 하면 돼요."
      else
        "'#{preset[:name]}' 스타일로 저장했어요. 이제 공개만 하면 돼요."
      end
      redirect_to action: :show, params: { slug: @member.slug, step: 4 }, notice: notice
    else
      redirect_to action: :show, params: { slug: @member.slug, step: 3 }, alert: "스타일 카드를 하나 누른 뒤 저장해 주세요."
    end
  end

  def update_layout
    key = params[:layout_preset].to_s
    preset = LayoutPreset.find(key)
    if preset
      @member.update!(layout_preset: key)
      redirect_to action: :show, params: { slug: @member.slug, step: 3 }, notice: "'#{preset[:name]}' 구성으로 저장했어요."
    else
      redirect_to action: :show, params: { slug: @member.slug, step: 3 }, alert: "구성 카드를 하나 누른 뒤 저장해 주세요."
    end
  end

  def publish
    @member.update!(published_at: Time.current)
    redirect_to "/#{@member.slug}", notice: "내 페이지를 공개했어요."
  end
end
