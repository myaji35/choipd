require "test_helper"

class LinkedinNewsletterDraftTest < ActiveSupport::TestCase
  setup do
    @account = ProfileAccount.create!(platform: "linkedin", display_name: "가상 인물")
  end

  test "defaults to draft and is removed with its account" do
    draft = @account.linkedin_newsletter_drafts.create!(title: "가상 초안")
    assert_equal "draft", draft.status
    assert_nil draft.archived_at

    assert_difference "LinkedinNewsletterDraft.count", -1 do
      @account.destroy!
    end
  end

  test "validates title body and status" do
    draft = @account.linkedin_newsletter_drafts.build(title: "", status: "unknown")
    assert_not draft.valid?
    assert draft.errors[:title].any?
    assert draft.errors[:status].any?

    draft.assign_attributes(title: "가" * 201, body: "가" * 100_001, status: "draft")
    assert_not draft.valid?
    assert draft.errors[:title].any?
    assert draft.errors[:body].any?
  end

  test "changes to the title or body clear approval" do
    draft = @account.linkedin_newsletter_drafts.create!(title: "제목", body: "본문")

    [ { title: "수정 제목" }, { body: "수정 본문" } ].each do |changes|
      draft.update!(approved_at: Time.current)
      draft.update!(changes)
      assert_nil draft.reload.approved_at
    end
  end
end
