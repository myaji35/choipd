require "test_helper"

class PublicPhotoVisitorTest < ActionDispatch::IntegrationTest
  setup do
    token = SecureRandom.hex(5)
    @member = Member.create!(name: "테스트 회원", email: "#{token}@example.com", slug: "member-#{token}", status: "approved", profession: "insurance_agent")
    @photo = @member.member_photos.create!(category: "daily", image: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png"))
  end

  test "사진 한 장 화면에서 누구인지·하는 일·문의 길을 보여 준다" do
    @member.member_services.create!(title: "상담", is_active: 1)
    @member.member_services.create!(title: "마감 서비스", is_active: 0)

    get public_photo_path(slug: @member.slug, photo_id: @photo.id)

    assert_response :success
    assert_select ".photo-owner .photo-owner-name a[href='/#{@member.slug}']", text: @member.name
    assert_select ".photo-owner .photo-owner-offer", text: /하는 일\s*상담/
    assert_not_includes response.body, "마감 서비스"
    assert_select ".photo-owner-actions a.primary[href='/#{@member.slug}#contact']", text: "상담·문의하기"
    assert_select ".photo-owner-actions a[href='/#{@member.slug}']", text: "#{@member.name}님 페이지 보기"
  end

  test "서비스가 없으면 하는 일 줄 없이 문의 버튼만 보여 준다" do
    get public_photo_path(slug: @member.slug, photo_id: @photo.id)

    assert_select ".photo-owner-offer", count: 0
    assert_select ".photo-owner-actions a.primary", text: "상담·문의하기"
  end

  test "사진 한 장 화면에도 imPD 플랫폼 메뉴·가입 띠·떠 있는 버튼을 보여 주지 않는다" do
    get public_photo_path(slug: @member.slug, photo_id: @photo.id)

    assert_select ".impd-joinstrip, nav.impd-topnav-links, .impd-nav-toggle, .impd-frap, nav.impd-topnav-visitor", count: 0
    assert_select ".impd-topnav a[href='/']", text: "imPD"
    assert_select ".impd-topnav a", text: /로그인|회원가입/, count: 0
  end

  test "영어 내부 값 대신 우리말로 적는다" do
    get public_photo_path(slug: @member.slug, photo_id: @photo.id)

    photo_body = response.body.split('<main class="photo-wrap"', 2).fetch(1)
    [ "보험 설계사", "일상", "#{@member.name}님이 올린 사진" ].each do |text|
      assert_includes photo_body, text
    end
    [ "insurance_agent", "DAILY", "MOMENT", "의 daily" ].each do |text|
      assert_not_includes photo_body, text
    end
    assert_select "meta[property='og:title'][content='#{@member.name} · 일상']"
    assert_select "meta[property='og:title'][content*='DAILY']", count: 0
  end

  test "로그인한 회원이 볼 때 위 띠는 지금 그대로다" do
    @member.update!(password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }

    get public_photo_path(slug: @member.slug, photo_id: @photo.id)

    assert_select ".impd-topnav a", text: "내 페이지"
    assert_select ".photo-owner"
  end
end
