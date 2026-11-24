require "test_helper"

class BrandChannelTest < ActiveSupport::TestCase
  setup do
    @brand = Brand.create!(name: "테스트 브랜드")
  end

  test "sets the connection method according to the platform" do
    expected = {
      "ego_session" => %w[naver_blog naver_people linkedin_profile],
      "oauth" => %w[linkedin_page facebook_page instagram threads],
      "manual" => %w[youtube kakao_channel other]
    }
    expected.each do |method, platforms|
      platforms.each do |platform|
        channel = @brand.brand_channels.create!(platform: platform)
        assert_equal method, channel.connection_method
        assert_equal "unknown", channel.session_status
        assert_equal 1, channel.tenant_id
      end
    end

    channel = @brand.brand_channels.create!(platform: "naver_blog", connection_method: "manual")
    assert_equal "manual", channel.connection_method
  end

  test "validates brand and enumerated fields" do
    channel = BrandChannel.new(platform: "invalid", connection_method: "invalid", session_status: "invalid")
    assert_not channel.valid?
    assert_equal %i[brand connection_method platform session_status], channel.errors.attribute_names.sort
  end

  test "requires linked SNS and profile accounts to exist and belong to the brand member" do
    owner = Member.create!(name: "브랜드 회원", email: "brand-owner@example.com", slug: "brand-owner")
    other_member = Member.create!(name: "다른 회원", email: "other-owner@example.com", slug: "other-owner")
    @brand.update!(member_id: owner.id)
    sns_account = SnsAccount.create!(member: other_member, platform: "facebook", account_name: "다른 페이지")
    profile_account = ProfileAccount.create!(member: other_member, platform: "naver_people", display_name: "다른 프로필")
    channel = @brand.brand_channels.build(platform: "other", sns_account: sns_account, profile_account: profile_account)

    assert_not channel.valid?
    assert channel.errors[:sns_account].present?
    assert channel.errors[:profile_account].present?

    sns_account.update!(member: owner)
    profile_account.update!(member: owner)
    assert channel.save!

    sns_account.destroy!
    profile_account.destroy!
    assert_not channel.valid?
    assert channel.errors[:sns_account].present?
    assert channel.errors[:profile_account].present?
  end

  test "rejects ego login for Instagram" do
    channel = @brand.brand_channels.build(platform: "instagram", connection_method: "ego_session")

    assert_not channel.valid?
    assert_includes channel.errors[:connection_method], "인스타그램은 계정 잠김 위험으로 ego 로그인 대신 공식 연동을 사용합니다"
  end

  test "copies the brand tenant on creation and update" do
    @brand.update!(tenant_id: 2)
    channel = @brand.brand_channels.create!(platform: "other", tenant_id: 99)
    assert_equal 2, channel.reload.tenant_id

    @brand.update!(tenant_id: 3)
    channel.update!(tenant_id: 99)
    assert_equal 3, channel.reload.tenant_id
  end

  test "accepts only HTTP and HTTPS profile addresses" do
    channel = @brand.brand_channels.build(platform: "other")
    [ "http://example.com", "https://example.com/channel", nil ].each do |url|
      channel.profile_url = url
      assert channel.valid?, url
    end
    [ "javascript:alert(1)", "//example.com", "https:/channel", "https://", "https://user:secret@example.com" ].each do |url|
      channel.profile_url = url
      assert_not channel.valid?, url
      assert channel.errors[:profile_url].present?
    end
  end

  test "accepts optional credential labels with a constrained format" do
    channel = @brand.brand_channels.build(platform: "other", credential_ref: "impd-Brand_1.naver")
    assert channel.valid?
    [ "한글", "my label", "item:secret", "a" * 65 ].each do |label|
      channel.credential_ref = label
      assert_not channel.valid?
      assert channel.errors[:credential_ref].present?
    end
  end

  test "detects delegation and deletes channels with the brand" do
    channel = @brand.brand_channels.create!(platform: "other")
    assert_not channel.delegated?
    channel.update!(delegation_consent_at: Time.current)
    assert channel.delegated?
    assert_difference("BrandChannel.count", -1) { @brand.destroy! }
  end
end
