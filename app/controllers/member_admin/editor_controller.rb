class MemberAdmin::EditorController < MemberAdmin::BaseController
  # 4단계 에디터: 업로드 → 정보 확인 → 스타일 선택 → 발행.
  # GET  /<slug>/admin/editor?step=N
  # PATCH /<slug>/admin/editor/update_info   (Step 2 저장)
  # PATCH /<slug>/admin/editor/update_style  (Step 3 저장)
  # PATCH /<slug>/admin/editor/publish       (Step 4 발행)
  def show
    @step = (params[:step] || 1).to_i.clamp(1, 4)
    @documents = @member.member_documents.order(uploaded_at: :desc)
    @portfolio_count = @member.member_portfolio_items.count
    @services_count  = @member.member_services.count
    @photos_count    = @member.member_photos.count
    @skills          = @member.member_skills.includes(:skill).joins(:skill).order(weight: :desc).limit(12)
    @doc_count       = @documents.size
    @presets         = ThemePreset::THEME_PRESETS
    @checklist       = build_checklist
  end

  def update_info
    permitted = params.require(:member).permit(:bio, :profession, :region, :phone, :email, :kakao_channel)
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
      redirect_to action: :show, params: { slug: @member.slug, step: 4 }, notice: "스타일 '#{preset[:name]}' 적용됨"
    else
      redirect_to action: :show, params: { slug: @member.slug, step: 3 }, alert: "유효한 스타일을 선택해 주세요"
    end
  end

  def publish
    @member.update!(published_at: Time.current)
    redirect_to "/#{@member.slug}", notice: "페이지가 발행되었습니다 🎉"
  end

  private

  def build_checklist
    [
      { key: "bio",        label: "자기소개 작성", done: @member.bio.to_s.length >= 20 },
      { key: "profession", label: "직업 설정",      done: @member.profession.present? && @member.profession != "custom" },
      { key: "region",     label: "지역 설정",      done: @member.region.present? },
      { key: "email",      label: "이메일",          done: @member.email.present? },
      { key: "phone",      label: "전화 연락처",    done: @member.phone.present? },
      { key: "photo",      label: "사진 1장 이상",  done: @photos_count.to_i > 0 },
      { key: "doc",        label: "이력 문서 1건",  done: @doc_count.to_i > 0 },
      { key: "skill",      label: "달란트 3개+",    done: @skills.size >= 3 },
      { key: "theme",      label: "스타일 선택",    done: @member.theme_preset.present? },
    ]
  end
end
