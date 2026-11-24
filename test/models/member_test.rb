require "test_helper"

class MemberTest < ActiveSupport::TestCase
  setup do
    @member = Member.create!(name: "OAuth member", email: "oauth-member@example.com", slug: "oauth-member")
    @image = "https://images.example.com/google-photo.jpg"
    @auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-member-id",
      info: { email: @member.email.upcase, email_verified: true, image: @image }
    )
  end

  test "links an existing member by email and fills the blank profile image" do
    assert_equal @member.id, Member.from_omniauth(@auth).id
    assert_equal @image, @member.reload.profile_image
    assert_equal @auth.provider, @member.provider
    assert_equal @auth.uid, @member.uid
  end

  test "fills only the profile image for a member matched by provider and uid" do
    @member.update!(provider: @auth.provider, uid: @auth.uid, profile_image: " ")
    original = @member.attributes
    @auth.info.email = "different@example.com"

    assert_equal @image, Member.from_omniauth(@auth).profile_image
    assert_equal original.merge("profile_image" => @image), @member.reload.attributes
  end

  test "preserves an existing profile image during linking and subsequent sign-in" do
    uploaded_image = "/uploads/member-photo.jpg"
    @member.update!(profile_image: uploaded_image)

    2.times do
      assert_equal @member.id, Member.from_omniauth(@auth).id
      assert_equal uploaded_image, @member.reload.profile_image
      assert_equal @auth.uid, @member.uid
    end
  end

  test "ignores an http profile image during linking and subsequent sign-in" do
    @auth.info.image = "http://images.example.com/google-photo.jpg"

    2.times do
      assert_equal @member.id, Member.from_omniauth(@auth).id
      assert_nil @member.reload.profile_image
      assert_equal @auth.uid, @member.uid
    end
  end

  test "preserves a profile image uploaded after the member was loaded" do
    stale_member = Member.find(@member.id)
    uploaded_image = "/uploads/new-member-photo.jpg"
    @member.update!(profile_image: uploaded_image)

    assert_equal false, stale_member.fill_profile_image(@image)
    assert_equal uploaded_image, @member.reload.profile_image
  end
end
