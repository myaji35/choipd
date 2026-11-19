require "test_helper"

class MemberAdmin::BrandConsentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = Member.create!(name: "동의 회원", email: "consent-#{SecureRandom.hex(4)}@example.com", slug: "consent-#{SecureRandom.hex(4)}", status: "approved", business_type: "individual", profession: "custom", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: @member.email, password: "password1234" }
  end

  test "screen grants and revokes with evidence" do
    get slug_admin_brand_consents_path(slug: @member.slug)
    assert_response :success
    assert_includes response.body, "먼저 SocialDoctors"
    patch slug_admin_brand_consents_path(slug: @member.slug), params: { consent_type: "socialdoctors_exposure", decision: "grant" }
    consent = ProConsent.current_for(@member.id, "socialdoctors_exposure")
    assert_equal ProConsent::SOCIALDOCTORS_EXPOSURE_TEXT, consent.consent_text
    assert consent.ip_address.present?
    patch slug_admin_brand_consents_path(slug: @member.slug), params: { consent_type: "socialdoctors_exposure", decision: "revoke" }
    assert consent.reload.revoked_at
    assert_nil ProConsent.current_for(@member.id, "socialdoctors_exposure")
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
