require "test_helper"

class SnsScheduledPostTest < ActiveSupport::TestCase
  test "validates Naver Blog content, channel delegation and member ownership" do
    owner = Member.create!(name: "채널 소유자", email: "blog-owner@example.com", slug: "blog-owner")
    other = Member.create!(name: "다른 회원", email: "blog-other@example.com", slug: "blog-other")
    channel = Brand.create!(name: "블로그 브랜드", member_id: owner.id).brand_channels.create!(platform: "naver_blog")
    post = SnsScheduledPost.new(platform: "naver_blog", brand_channel: channel, member: other,
      title: "가" * 101, scheduled_at: Time.current)

    assert_not post.valid?
    assert post.errors[:title].any?
    assert post.errors[:message].any?
    assert post.errors[:brand_channel].any?
    assert_includes post.errors[:base], "브랜드 채널의 운영 위탁 동의가 필요합니다."

    post.assign_attributes(member: owner, title: "제목", message: "본문")
    channel.update!(platform: "naver_people", delegation_consent_at: Time.current)
    assert_not post.valid?
    assert_includes post.errors[:brand_channel], "네이버 블로그 채널을 선택해 주세요."

    channel.update!(platform: "naver_blog")
    assert post.valid?
  end

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

  test "changes to the message or time clear LinkedIn approval" do
    profile = ProfileAccount.create!(platform: "linkedin", display_name: "공유 계정")
    record = profile.linkedin_share_posts.create!(platform: "linkedin", message: "초안", scheduled_at: 1.day.from_now, status: "draft")
    [ { message: "수정" }, { scheduled_at: 2.days.from_now } ].each do |changes|
      record.update!(approved_at: Time.current, status: "scheduled")
      record.update!(changes)
      assert_nil record.reload.approved_at
      assert record.status_draft?
    end
  end

  test "only LinkedIn shares have the 3000 character limit" do
    profile = ProfileAccount.create!(platform: "linkedin", display_name: "공유 계정")
    record = profile.linkedin_share_posts.build(platform: "linkedin", message: "가" * 3000, scheduled_at: Time.current)
    assert_predicate record, :valid?

    record.message += "나"
    assert_not record.valid?
    assert record.errors[:message].any?

    record.profile_account = nil
    assert_predicate record, :valid?
  end
end
