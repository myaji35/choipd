class MemberAdmin::EditorController < MemberAdmin::BaseController
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
    @checklist       = build_checklist
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
      redirect_to action: :show, params: { slug: @member.slug, step: 3 }, notice: "정보가 저장되었습니다"
    else
      redirect_to action: :show, params: { slug: @member.slug, step: 2 }, alert: @member.errors.full_messages.join(" · ")
    end
  end

  def update_style
    key = params[:theme_preset].to_s
    preset = ThemePreset.find(key)
    if preset
      @member.update!(theme_preset: key)
      redirect_to action: :show, params: { slug: @member.slug, step: 4 }, notice: "'#{preset[:name]}' 스타일로 저장했어요. 이제 공개만 하면 돼요."
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

  private

  def build_checklist
    [
      { key: "bio",        label: "자기소개 쓰기", done: @member.bio.to_s.length >= 20 },
      { key: "profession", label: "직업 정하기",      done: @member.profession.present? && @member.profession != "custom" },
      { key: "region",     label: "지역 정하기",      done: @member.region.present? },
      { key: "email",      label: "이메일 적기",          done: @member.email.present? },
      { key: "phone",      label: "전화번호 적기",    done: @member.phone.present? },
      { key: "photo",      label: "사진 1장 이상 올리기",  done: @photos_count.to_i > 0 },
      { key: "doc",        label: "이력·경력 문서 1개 올리기",  done: @doc_count.to_i > 0 },
      { key: "skill",      label: "자료에서 찾은 강점 3개 이상",    done: @skills.size >= 3 },
      { key: "theme",      label: "스타일 고르기",    done: @member.theme_preset.present? }
    ]
  end
end
