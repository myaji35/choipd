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
end
