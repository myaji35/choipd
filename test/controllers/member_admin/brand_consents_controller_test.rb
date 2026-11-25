require "test_helper"

class MemberAdmin::BrandConsentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(name: "동의 회원", email: "consent-#{SecureRandom.hex(4)}@example.com", slug: "consent-#{SecureRandom.hex(4)}", status: "approved", business_type: "individual", profession: "custom", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "screen grants and revokes with evidence" do
    get slug_admin_brand_consents_path(slug: @member.slug)
    assert_response :success
    assert_select "#townin-consent a[href='#socialdoctors-consent']", text: "'SNS 대신 운영'에 먼저 동의해야 해요"
    patch slug_admin_brand_consents_path(slug: @member.slug), params: { consent_type: "socialdoctors_exposure", decision: "grant" }
    consent = ProConsent.current_for(@member.id, "socialdoctors_exposure")
    assert_equal ProConsent::SOCIALDOCTORS_EXPOSURE_TEXT, consent.consent_text
    assert consent.ip_address.present?
    patch slug_admin_brand_consents_path(slug: @member.slug), params: { consent_type: "socialdoctors_exposure", decision: "revoke" }
    assert consent.reload.revoked_at
    assert_nil ProConsent.current_for(@member.id, "socialdoctors_exposure")
  end

  test "동의 화면은 내 브랜드와 같은 이름을 쓰고 비용을 펼치지 않아도 보여 준다" do
    path = slug_admin_brand_consents_path(slug: @member.slug)
    patch path, params: { consent_type: "socialdoctors_exposure", decision: "grant" }
    get path

    assert_select "#socialdoctors-consent h2", text: "SNS 대신 운영"
    assert_select "#townin-consent h2", text: "우리 동네 광고"
    assert_select "#townin-consent > dl strong", text: /1명당 50원/
    assert_select "#socialdoctors-consent button", text: "그만두기"
    assert_select "#townin-consent button:not([disabled])", text: "동의하기"
  end

  test "동의·그만두기 뒤 달라진 점을 알려 준다" do
    path = slug_admin_brand_consents_path(slug: @member.slug)
    patch path, params: { consent_type: "socialdoctors_exposure", decision: "grant" }
    assert_equal "'SNS 대신 운영'에 동의했어요. 운영팀이 준비를 시작해요.", flash[:notice]

    patch path, params: { consent_type: "socialdoctors_exposure", decision: "revoke" }
    assert_equal "'SNS 대신 운영'을 그만뒀어요. 새 글이 올라가지 않아요.", flash[:notice]
  end

  test "townin grant requires exposure consent" do
    path = slug_admin_brand_consents_path(slug: @member.slug)
    patch path, params: { consent_type: "townin_local_ads", decision: "grant" }
    assert_nil ProConsent.current_for(@member.id, "townin_local_ads")
    patch path, params: { consent_type: "socialdoctors_exposure", decision: "grant" }
    patch path, params: { consent_type: "townin_local_ads", decision: "grant" }
    assert ProConsent.current_for(@member.id, "townin_local_ads")
  end
end
