require "test_helper"

class SnsScheduledPostTest < ActiveSupport::TestCase
  setup do
    @member = Member.create!(name: "예약 회원", email: "scheduled@example.com", slug: "scheduled-member")
    @brand = Brand.create!(name: "예약 브랜드", member_id: @member.id)
    @account = SnsAccount.create!(member: @member, platform: "facebook", account_name: "예약 페이지")
    @attributes = { member: @member, sns_account: @account, platform: "facebook", message: "게시 내용", scheduled_at: 1.hour.from_now }
  end

  test "blocks creation if any matching channel on the member's brands lacks consent" do
    @brand.brand_channels.create!(platform: "facebook_page", sns_account: @account, delegation_consent_at: Time.current)
    channel = @brand.brand_channels.create!(platform: "facebook_page", sns_account: @account)
    post = SnsScheduledPost.new(@attributes)

    assert_not post.save
    assert_includes post.errors[:base], "브랜드 채널의 운영 위탁 동의가 필요합니다."
    post_without_member = SnsScheduledPost.new(@attributes.except(:member))
    assert_not post_without_member.valid?
    assert_includes post_without_member.errors[:base], "브랜드 채널의 운영 위탁 동의가 필요합니다."

    channel.update!(delegation_consent_at: Time.current)
    assert post.save!
  end

  test "keeps existing behavior without a matching member channel" do
    @brand.brand_channels.create!(platform: "facebook_page")
    assert SnsScheduledPost.create!(@attributes).persisted?
    assert SnsScheduledPost.create!(@attributes.except(:sns_account)).persisted?
  end

  test "rejects changing a scheduled post to an account without delegation consent" do
    post = SnsScheduledPost.create!(@attributes)
    @brand.brand_channels.create!(platform: "facebook_page", sns_account: @account)
    unconsented_account = SnsAccount.create!(member: @member, platform: "facebook", account_name: "다른 예약 페이지")
    @brand.brand_channels.create!(platform: "facebook_page", sns_account: unconsented_account)

    assert post.update(message: "수정한 게시 내용")
    assert_not post.update(sns_account: unconsented_account)
    assert_includes post.errors[:base], "브랜드 채널의 운영 위탁 동의가 필요합니다."
    assert_equal @account.id, post.reload.sns_account_id
  end
end
