require "test_helper"
require "uri"

class MemberAdminEditorFlowTest < ActionDispatch::IntegrationTest
  setup do
    slug = "editor-flow-#{SecureRandom.hex(4)}"
    @member = Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug,
      status: "approved", business_type: "individual", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "자료 올리기에는 다음 버튼이 있다" do
    get slug_admin_editor_path(slug: @member.slug, step: 1)

    assert_response :ok
    upload_hub = response.body[/<section data-controller="upload-hub"[^>]*>.*?<\/section>/m]
    assert_match(/<div id="media"[^>]*>.*<\/div>\s*<\/section>\z/m, upload_hub.to_s)
    assert_select "a.impd-btn-primary[href='?step=2']", text: "다음 →"
    assert_includes response.body, "올린 파일은 바로 저장돼요"
    assert_select "ul.editor-file-rules li", count: 3
    assert_not_includes response.body, "포트폴리오"
    assert_not_includes response.body, "자동 분류"
    assert_not_includes response.body, "당신의 페이지"
  end

  test "글 파일이 없어도 자료 단계에서 직접 적을 수 있다" do
    assert_difference -> { @member.member_documents.count }, 1 do
      post slug_admin_documents_path(slug: @member.slug, format: :json), params: {
        filename: "직접 쓴 글 2026-11-25 1305.txt", category: "career",
        content: "2010년부터 보험 설계사로 일하고 있어요."
      }, as: :json
      assert_response :created
    end
    assert_equal "직접 쓴 글 2026-11-25 1305.txt", @member.member_documents.sole.filename
  end

  test "자료 목록이 비어 있거나 채워져 있어도 바로 적기 칸을 보여 준다" do
    path = slug_admin_editor_path(slug: @member.slug, step: 1)
    assert_write_doc = -> do
      get path

      assert_response :ok
      assert_select "#write-doc" do
        assert_select "label[for=doc_paste_text]", text: "이력·경력을 여기에 바로 적어 주세요"
        assert_select "button[data-action='click->member-doc-uploader#uploadText']", text: "이 글 올리기"
      end
      assert_operator response.body.index('id="write-doc"'), :<, response.body.index('data-member-doc-uploader-target="fileInput"')
      assert_includes response.body, "글 파일(.txt)이 있으면 올려도 돼요"
      assert_not_includes response.body, "메모장"
    end

    assert_write_doc.call
    @member.member_documents.create!(tenant_id: 1, filename: "career.txt", category: "career", content_md: "경력 메모")
    assert_write_doc.call
  end

  test "자료와 사진을 올릴 때 쉬운 안내를 쓴다" do
    doc, photo = %w[member_doc_uploader member_photo_uploader].map do |name|
      File.read(Rails.root.join("app/javascript/controllers/#{name}_controller.js"))
    end
    [ doc, photo ].each do |source|
      [ "메모장", "확장자 불가", "업로드 중", "업로드 완료", "HTTP $" ].each do |phrase|
        assert_not_includes source, phrase
      end
    end
    assert_includes doc, "uploadText"
    assert_includes doc, "직접 쓴 글"
  end

  test "정보 확인 단계에서 저장과 건너뛰기를 구분하고 쉬운 말을 쓴다" do
    get slug_admin_editor_path(slug: @member.slug, step: 2)

    assert_response :ok
    assert_select "a.impd-btn-primary", text: /다음/, count: 0
    assert_select "a.editor-skip-link[href='?step=3']", text: /저장하지 않고 다음 단계 보기/
    [ "역량", "포트폴리오", "자동 추출" ].each { |phrase| assert_not_includes response.body, phrase }
    assert_includes response.body, "작업 사진·사례"
    assert_select ".editor-pair", count: 2
  end

  test "프로필 사진 양식은 쓰던 정보와 별도로 제출한다" do
    path = slug_admin_editor_path(slug: @member.slug, step: 2)
    get path

    assert_response :ok
    assert_select '#profile-photo form[data-action*="editor-info#submitProfilePhoto"]', minimum: 1
    assert_select '#profile-photo form[data-action*="editor-info#submitProfilePhoto"] input[type=file][data-action~="change->editor-info#uploadProfilePhoto"]:not([disabled])', count: 1
    assert_select '#profile-photo [data-editor-info-target="photoStatus"][role=status]', count: 1
    assert_select "#profile-photo noscript button[type=submit]", text: "저장"
    assert_includes response.body, "사진을 올려도 아래에 쓰던 글은 그대로 남아요."

    @member.member_photos.create!(category: "people", image: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png"))
    get path
    assert_select '.profile-photo-choices form[data-action*="submitProfilePhoto"]', count: 1

    source = Rails.root.join("app/javascript/controllers/editor_info_controller.js").read
    [ "submitProfilePhoto", "DOMParser", "사진을 올리는 중이에요" ].each do |phrase|
      assert_includes source, phrase
    end
  end

  test "정보 확인 단계의 입력 칸은 흰 바탕이다" do
    get slug_admin_editor_path(slug: @member.slug, step: 2)

    assert_response :ok
    assert_match(/\.editor-fields :is\(input, textarea\)\s*\{[^}]*background: #fff/, response.body)
  end

  test "문서 유무에 맞게 강점 안내를 보여 준다" do
    path = slug_admin_editor_path(slug: @member.slug, step: 2)
    get path

    assert_response :ok
    assert_select "a[href='?step=1&tab=docs#docs']", text: "← 글 올리러 가기"
    assert_not_includes response.body, "글 더 올리기"

    @member.member_documents.create!(tenant_id: 1, filename: "career.txt", category: "career", content_md: "경력 메모")
    get path

    assert_response :ok
    assert_includes response.body, "아직 강점을 찾지 못했어요"
    assert_select "a[href='?step=1&tab=docs#docs']", text: "글 더 올리기"
    assert_not_includes response.body, "글 올리러 가기"
    assert_select "label[for=member_phone]", text: "전화번호 (선택)"
    assert_includes response.body, "min-height: 48px"
    assert_not_includes response.body, "카카오톡 채널 URL"
  end

  test "정보 확인 단계에서 지금까지 넣은 것을 고치러 갈 수 있다" do
    get slug_admin_editor_path(slug: @member.slug, step: 2)

    assert_response :ok
    assert_select ".impd-card[aria-labelledby=editor-added-materials-title]" do
      assert_select "h2", text: "지금까지 넣은 것"
      assert_select "a[href='?step=1&tab=docs#docs']"
      assert_select "a[href='?step=1&tab=media#media']"
      assert_select "a[href=?]", slug_admin_services_path(slug: @member.slug)
    end
    assert_not_includes Nokogiri::HTML(response.body).at_css("body").text, "문서"
  end

  test "공개 단계의 준비 항목은 대시보드와 같다" do
    get slug_admin_dashboard_path(slug: @member.slug)
    assert_response :ok
    dashboard_count = css_select("summary").map(&:text).filter_map { |text| text[/준비 항목 6개 중 (\d+)개 마쳤어요/, 1] }.first
    assert dashboard_count

    get slug_admin_editor_path(slug: @member.slug, step: 4)
    assert_response :ok
    assert_select "h2.impd-label", text: "내 페이지 준비 항목"
    assert_select "span.impd-display", text: "#{dashboard_count}/6"
    MemberAdmin::ChecklistHelper::CHECKLIST_LABELS.values.each do |label|
      assert_select "li", text: /#{Regexp.escape(label)}/
    end
    assert_not_includes response.body, "강점 3개 이상"
    assert_not_includes response.body, "하러 가기"
    assert_no_match(/준비 \d+%/, response.body)
    assert_select ".editor-page a[href*='from=checklist']", count: 0
    %w[profile-photo bio profession-region media new-service docs].each do |anchor|
      assert_select ".editor-page li a[href$='##{anchor}']", count: 1
    end
  end

  test "기본 정보가 없으면 공개 버튼이 꺼져 있고 갈 곳을 알려 준다" do
    path = slug_admin_editor_path(slug: @member.slug, step: 4)
    get path

    assert_response :ok
    assert_select "button[type=submit][disabled]", count: 1
    assert_includes response.body, "공개하려면 아직 필요해요:"
    assert_select "#publish-ready-hint", count: 0
    assert_select "strong", text: "자기소개 20자 이상 · 직업"
    assert_select "a[href$='step=2#bio']", text: "내 정보 적으러 가기 →"

    @member.update!(bio: "스마트폰으로 영상 만드는 법을 가르치는 강사입니다.", profession: "educator", email: @member.email)
    get path

    assert_response :ok
    assert_select "button[type=submit][disabled]", count: 0
    assert_select "button[type=submit]", text: "지금 공개하기"
  end

  test "공개할 수 있으면 남은 준비 항목 개수를 공개 버튼 위에 보여 준다" do
    @member.update!(bio: "가" * 50, profession: "educator", region: "서울", profile_image: "/icon.png")
    @member.member_photos.create!(category: "daily", image: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png"))
    @member.member_services.create!(title: "보장 분석 상담")
    path = slug_admin_editor_path(slug: @member.slug, step: 4)

    get path

    assert_response :ok
    assert_select "#publish-ready-hint", text: "지금 공개할 수 있어요. 남은 준비 항목 1개는 공개한 뒤에 채워도 돼요."
    assert_select "#publish-ready-hint + form button", text: "지금 공개하기"

    @member.member_documents.create!(tenant_id: 1, filename: "career.txt", category: "career", content_md: "경력 메모")
    get path

    assert_response :ok
    assert_select "#publish-ready-hint", text: "준비를 모두 마쳤어요. 이제 공개만 하면 돼요."
  end

  test "직업만 빠졌으면 직업 입력 칸으로 안내한다" do
    @member.update!(bio: "가" * 30)

    get slug_admin_editor_path(slug: @member.slug, step: 4)

    assert_response :ok
    assert_select "p", text: "공개하려면 아직 필요해요: 직업" do
      assert_select "strong", text: "직업"
    end
    assert_select "a[href$='#profession-region']", text: "내 정보 적으러 가기 →"
  end

  test "앞 단계로 돌아가도 마친 단계가 표시된다" do
    @member.update!(bio: "가" * 30, profession: "educator")

    get slug_admin_editor_path(slug: @member.slug, step: 1)

    assert_response :ok
    assert_select "a[href='?step=2']", text: /정보 확인.*\(마침\)/
    assert_select "a[href='?step=1'][aria-current='step']"
  end

  test "자기소개 길이에 따라 공개와 준비 기준을 안내한다" do
    {
      10 => "20자를 넘기면 내 페이지를 공개할 수 있어요.",
      30 => "공개할 수 있어요. 50자를 넘기면 준비 항목 '자기소개'가 채워져요.",
      60 => "충분해요."
    }.each do |length, hint|
      @member.update!(bio: "가" * length)

      get slug_admin_editor_path(slug: @member.slug, step: 2)

      assert_response :ok
      assert_select "#member_bio_count", text: "#{length} / 200자 · #{hint}"
      assert_not_includes response.body, "50자 이상 권장"
    end
  end

  test "정보를 저장하면 스타일을 고르도록 안내한다" do
    patch slug_admin_editor_update_info_path(slug: @member.slug), params: { member: { bio: "가" * 30 } }

    assert_redirected_to slug_admin_editor_path(slug: @member.slug, step: 3)
    assert_equal "내 정보를 저장했어요. 이제 스타일을 골라 주세요.", flash[:notice]
  end

  test "공개한 뒤 4단계에서 주소를 공유할 수 있다" do
    @member.update!(bio: "가" * 30, profession: "educator")

    patch slug_admin_editor_publish_path(slug: @member.slug)

    assert_redirected_to slug_admin_editor_path(slug: @member.slug, step: 4, published: 1)
    assert_not_nil @member.reload.published_at
    follow_redirect!
    assert_select "#publish-done[role=status] strong", text: "공개했어요."
    assert_select "#publish-next-actions" do
      assert_select "button[type=button][data-page-path=?]", "/#{@member.slug}", text: "주소 복사"
      assert_select "a[href=?][target=_blank]", "/#{@member.slug}", text: "내 페이지 보기"
    end
  end

  test "공개한 회원에게 다시 공개하는 버튼 대신 상태를 보여 준다" do
    @member.update!(published_at: Time.utc(2026, 11, 24, 18), theme_preset: nil)

    get slug_admin_editor_path(slug: @member.slug, step: 4)

    assert_select "h1", text: "내 페이지가 공개돼 있어요"
    assert_select ".impd-label-muted", text: "● 공개 중 · 2026.11.25부터"
    assert_select "a[href='?step=3']", text: /스타일.*\(마침\)/
    assert_select "form[action=?]", slug_admin_editor_publish_path(slug: @member.slug), count: 0
    assert_not_includes response.body, "다시 공개하기"
    assert_includes response.body, "다시 공개할 필요는 없어요"
    assert_select "#publish-ready-hint", count: 0
    assert_select "#publish-done", count: 0
  end

  test "아직 공개하지 않았으면 주소에 표시를 붙여도 완료 안내를 숨긴다" do
    get slug_admin_editor_path(slug: @member.slug, step: 4, published: 1)

    assert_select "#publish-done", count: 0
    assert_select "button[type=submit]", text: "지금 공개하기"
  end

  test "기본 스타일과 직접 고른 스타일 모두 마침을 표시한다" do
    @member.update!(theme_preset: nil)
    path = slug_admin_editor_path(slug: @member.slug, step: 4)

    get path
    assert_select "a[href='?step=3']" do
      assert_select "p", text: "기본 스타일로 준비됐어요"
      assert_select "p span", text: "(마침)"
    end
    assert_not_includes response.body, "기본 그대로"

    @member.update!(theme_preset: "clean")
    get path
    assert_select "a[href='?step=3']" do
      assert_select "p", text: "깔끔한"
      assert_select "p span", text: "(마침)"
    end
    assert_not_includes response.body, "기본 그대로"
  end

  test "이메일 저장 실패 후 입력값을 유지하고 수정한 정보는 다시 저장할 수 있다" do
    original_bio, original_email = @member.bio, @member.email
    path = slug_admin_editor_update_info_path(slug: @member.slug)
    info = {
      email: "abc", bio: ("새로 쓴 자기소개입니다. " * 4).strip, career_note: "새로 쓴 경력",
      profession: "custom", custom_profession: "스마트폰 강사", region: "서울",
      kakao_channel: "https://pf.kakao.com/example"
    }

    patch path, params: { member: info }

    assert_response :unprocessable_entity
    assert_select "#info-errors[role=alert] strong", text: /쓴 내용은 그대로 남아 있어요/
    assert_select "textarea#member_bio", text: info[:bio].strip
    assert_select "textarea#member_career_note", text: info[:career_note]
    assert_select "input#member_email[value=abc][aria-invalid=true][aria-describedby=member_email_error]"
    assert_select "#member_email_error", text: /이메일 주소 모양이 맞지 않아요/
    assert_select "select#member_profession option[value=custom][selected]"
    assert_select "input#member_custom_profession[value=?]", info[:custom_profession]
    assert_select "input#member_kakao_channel[value=?]", info[:kakao_channel]
    assert_select "a[aria-current=step]", text: /정보 확인/
    assert_select "a[aria-current=step] span", text: "(마침)", count: 0
    assert_select "a[href=?]", slug_admin_editor_path(slug: @member.slug, step: 3), text: /스타일/
    @member.reload
    assert_equal [ original_bio, original_email ], [ @member.bio, @member.email ]

    patch path, params: { member: info.merge(email: original_email) }

    assert_redirected_to slug_admin_editor_path(slug: @member.slug, step: 3)
    assert_equal info[:bio], @member.reload.bio
  end

  test "비었거나 다른 회원이 쓰는 이메일에는 알맞은 문구를 표시한다" do
    other = Member.create!(name: "다른 회원", slug: "other-#{@member.slug}", email: "other-#{@member.email}",
      password: "password1234", password_confirmation: "password1234")
    {
      "" => "이메일을 적어 주세요. 고객 문의가 이 주소로 와요.",
      other.email => "이미 다른 회원이 쓰는 이메일이에요. 다른 주소를 적어 주세요."
    }.each do |email, message|
      patch slug_admin_editor_update_info_path(slug: @member.slug), params: { member: { email: email } }

      assert_response :unprocessable_entity
      assert_select "#info-errors li", text: message, count: 1
      assert_select "#member_email_error", text: message
    end
  end

  test "올릴 수 없는 문서는 글 파일로 저장하는 방법을 안내한다" do
    post slug_admin_documents_path(slug: @member.slug, format: :json), params: { filename: "a.pdf", content: "x" }

    assert_response :unprocessable_entity
    assert_equal "INVALID_EXT", response.parsed_body.fetch("error")
    assert_equal "이 파일은 올릴 수 없어요. 글 파일(.txt)로 저장해서 올려 주세요.", response.parsed_body.fetch("message")
  end

  test "스타일 선택 단계에서 건너뛰기와 저장 방법을 안내한다" do
    get slug_admin_editor_path(slug: @member.slug, step: 3)

    assert_response :ok
    assert_select "a.impd-btn-primary", text: /다음/, count: 0
    assert_select "a.editor-skip-link[href='?step=4']", text: /저장하지 않고 다음 단계 보기/
    assert_includes response.body, "골랐어요"
    assert_select "p", text: "'✓ 골랐어요'가 붙은 카드는 아직 저장 전이에요. 이 버튼을 눌러야 내 페이지에 반영돼요."
    assert_select "form[action=?]", slug_admin_editor_update_style_path(slug: @member.slug), count: 1 do
      assert_select "button[type=submit]", count: 1
    end
    assert_select "form[action=?]", slug_admin_editor_update_layout_path(slug: @member.slug), count: 0
    assert_select "input[name=theme_preset][value=editorial][checked]"
    assert_select "input[name=layout_preset][value=editorial][checked]"
    assert_not_includes response.body, "아직 고르지 않았어요"
    assert_includes response.body, "지금: 잡지형 (기본)"
    assert_not_includes response.body, "에디토리얼"
  end

  test "현재 스타일과 구성 카드에만 지금 내 페이지를 표시한다" do
    @member.update!(theme_preset: "clean")
    get slug_admin_editor_path(slug: @member.slug, step: 3)

    assert_response :ok
    assert_equal 2, response.body.scan("지금 내 페이지").size
    assert_not_includes response.body, "사용 중"
    assert_select ".is-saved", count: 2
    assert_select ".theme-radio[checked] + .theme-card.is-saved", text: /지금 내 페이지/
    assert_select ".layout-radio[checked] + .layout-card.is-saved", text: /지금 내 페이지/
    assert_includes response.body, ".layout-radio:checked + .layout-card.is-saved::after { content: none; }"
  end

  test "스타일과 구성을 한 번에 저장한다" do
    patch slug_admin_editor_update_style_path(slug: @member.slug), params: { theme_preset: "warm", layout_preset: "grid" }

    assert_response :redirect
    query = Rack::Utils.parse_query(URI.parse(response.location).query)
    assert_equal "4", query["step"]
    assert_includes query["notice"], "'따뜻한' 스타일과 '카드 모음형' 구성으로 저장했어요"
    @member.reload
    assert_equal "warm", @member.theme_preset
    assert_equal "grid", @member.layout_preset
  end

  test "구성 값이 틀리면 스타일만 저장한다" do
    @member.update!(layout_preset: "grid")

    patch slug_admin_editor_update_style_path(slug: @member.slug), params: { theme_preset: "warm", layout_preset: "nope" }

    assert_response :redirect
    query = Rack::Utils.parse_query(URI.parse(response.location).query)
    assert_equal "4", query["step"]
    assert_equal "'따뜻한' 스타일로 저장했어요. 이제 공개만 하면 돼요.", query["notice"]
    @member.reload
    assert_equal "warm", @member.theme_preset
    assert_equal "grid", @member.layout_preset
  end

  test "스타일을 저장한 적 없으면 4단계에서 기본 스타일을 알려 준다" do
    get slug_admin_editor_path(slug: @member.slug, step: 4)

    assert_response :ok
    assert_includes response.body, "스타일: 잡지형 (기본)"
    assert_not_includes response.body, "스타일을 아직 고르지 않았어요"
    assert_select "a[href='?step=3']", text: "바꾸기"
  end

  test "스타일을 고르지 않고 저장하면 선택 방법을 안내한다" do
    patch slug_admin_editor_update_style_path(slug: @member.slug)

    assert_response :redirect
    location = URI.parse(response.location)
    assert_equal slug_admin_editor_path(slug: @member.slug), location.path
    query = Rack::Utils.parse_query(location.query)
    assert_equal "3", query["step"]
    assert_equal "스타일 카드를 하나 누른 뒤 저장해 주세요.", query["alert"]
  end
end
