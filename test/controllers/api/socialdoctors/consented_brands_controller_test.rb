require "test_helper"

class Api::Socialdoctors::ConsentedBrandsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_key = ENV["SOCIALDOCTORS_API_KEY"]
    ENV["SOCIALDOCTORS_API_KEY"] = "test-key"
    @member = Member.create!(name: "API 회원", email: "api-#{SecureRandom.hex(4)}@example.com", slug: "api-#{SecureRandom.hex(4)}", bio: "소개", social_links: '{"instagram":"https://example.com"}')
    @consent = ProConsent.create!(owner_id: @member.id, consent_type: "socialdoctors_exposure", consented: true, consented_at: Time.current)
    @brand = Brand.create!(member_id: @member.id, name: "브랜드", slug: "brand-#{SecureRandom.hex(4)}")
  end

  teardown { ENV["SOCIALDOCTORS_API_KEY"] = @previous_key }

  test "authentication and configuration" do
    get "/api/socialdoctors/consented-brands", headers: { "X-Api-Key" => "wrong" }
    assert_response :unauthorized
    ENV.delete("SOCIALDOCTORS_API_KEY")
    get "/api/socialdoctors/consented-brands"
    assert_response :service_unavailable
  end

  test "contract and changes including revocation" do
    headers = { "X-Api-Key" => "test-key" }
    get "/api/socialdoctors/consented-brands", headers: headers
    assert_response :success
    body = response.parsed_body
    assert_equal %w[brands syncedAt], body.keys.sort
    item = body["brands"].find { |b| b["externalId"] == "m_#{@member.id}" }
    assert_equal @brand.id, item["brands"].first["id"]
    assert_equal false, item["townInLocalAds"]
    assert_equal({ "instagram" => "https://example.com" }, item["socialLinks"])
    assert_not_includes response.body, @member.email
    assert_not item.key?("phone")
    get "/api/socialdoctors/consented-brands", params: { since: 1.minute.from_now.iso8601 }, headers: headers
    assert_empty response.parsed_body["brands"]
    @consent.revoke!
    get "/api/socialdoctors/consented-brands", params: { since: 1.minute.ago.iso8601 }, headers: headers
    item = response.parsed_body["brands"].find { |b| b["externalId"] == "m_#{@member.id}" }
    assert item["revokedAt"].present?
  end

  test "excludes members without exposure consent" do
    no_consent_member = Member.create!(name: "미동의 회원", email: "api-#{SecureRandom.hex(4)}@example.com", slug: "api-#{SecureRandom.hex(4)}", bio: "소개", social_links: '{"instagram":"https://example.com"}')
    local_ads_member = Member.create!(name: "지역 광고 동의 회원", email: "api-#{SecureRandom.hex(4)}@example.com", slug: "api-#{SecureRandom.hex(4)}", bio: "소개", social_links: '{"instagram":"https://example.com"}')
    ProConsent.create!(owner_id: local_ads_member.id, consent_type: "townin_local_ads", consented: true, consented_at: Time.current)

    get "/api/socialdoctors/consented-brands", headers: { "X-Api-Key" => "test-key" }
    assert_response :success
    external_ids = response.parsed_body["brands"].pluck("externalId")
    assert_not_includes external_ids, "m_#{no_consent_member.id}"
    assert_not_includes external_ids, "m_#{local_ads_member.id}"
    assert_includes external_ids, "m_#{@member.id}"
  end

  test "includes withdrawn members with withdrawnAt" do
    @member.update_column(:withdrawn_at, Time.current)

    get "/api/socialdoctors/consented-brands", headers: { "X-Api-Key" => "test-key" }
    assert_response :success
    item = response.parsed_body["brands"].find { |brand| brand["externalId"] == "m_#{@member.id}" }
    assert item, "Expected the withdrawn member in brands"
    assert item["withdrawnAt"].present?
  end
end
