require "test_helper"

class Pd::ProfileAccountNewsletterDraftsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = AdminUser.create!(email: "newsletter-test@example.test", password: "password123", role: "pd")
    sign_in @admin
    @account = ProfileAccount.create!(platform: "linkedin", display_name: "가상 인물", tenant_id: 2)
    @return_path = pd_profile_account_path(@account, anchor: "newsletter-drafts")
  end

  test "creates edits archives and restores a local draft" do
    assert_difference "LinkedinNewsletterDraft.count", 1 do
      post pd_profile_account_newsletter_drafts_path(@account),
        params: { linkedin_newsletter_draft: { newsletter_name: "Dev Notes", title: "가상 초안", body: "본문", tenant_id: 3, status: "archived" } }
    end
    assert_response :see_other
    assert_redirected_to @return_path
    assert_equal "뉴스레터 초안을 저장했습니다.", flash[:notice]
    draft = @account.linkedin_newsletter_drafts.sole
    assert_equal [ "Dev Notes", "가상 초안", "본문", 2, "draft" ], draft.attributes.symbolize_keys.values_at(:newsletter_name, :title, :body, :tenant_id, :status)

    get edit_pd_profile_account_newsletter_draft_path(@account, draft)
    assert_response :success
    assert_select "textarea", text: "본문"

    patch pd_profile_account_newsletter_draft_path(@account, draft), params: { linkedin_newsletter_draft: { title: "수정한 초안" } }
    assert_response :see_other
    assert_redirected_to @return_path
    assert_equal "수정한 초안", draft.reload.title

    patch archive_pd_profile_account_newsletter_draft_path(@account, draft)
    assert_response :see_other
    assert_equal "archived", draft.reload.status
    assert draft.archived_at
    follow_redirect!
    assert_select "details", text: /수정한 초안.*되살리기/m

    patch restore_pd_profile_account_newsletter_draft_path(@account, draft)
    assert_response :see_other
    assert_equal "draft", draft.reload.status
    assert_nil draft.archived_at
  end

  test "returns 404 for a draft from another account" do
    other = ProfileAccount.create!(platform: "linkedin", display_name: "다른 계정")
    draft = other.linkedin_newsletter_drafts.create!(title: "다른 계정 초안")
    get edit_pd_profile_account_newsletter_draft_path(@account, draft)
    assert_response :not_found

    sign_in @admin
    patch archive_pd_profile_account_newsletter_draft_path(@account, draft)
    assert_response :not_found
    assert_equal "draft", draft.reload.status
  end

  test "rejects non LinkedIn accounts" do
    naver = ProfileAccount.create!(platform: "naver_people", display_name: "네이버 계정")
    assert_no_difference "LinkedinNewsletterDraft.count" do
      post pd_profile_account_newsletter_drafts_path(naver), params: { linkedin_newsletter_draft: { title: "가상 초안" } }
    end
    assert_redirected_to pd_profile_account_path(naver)
    assert flash[:alert].present?
  end

  test "reports validation errors when creating or updating" do
    path = pd_profile_account_newsletter_drafts_path(@account)
    title = "가" * 201
    assert_no_difference "LinkedinNewsletterDraft.count" do
      post path, params: { linkedin_newsletter_draft: { newsletter_name: "Dev Notes", title: title, body: "작성 중인 본문" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert] li"
    assert_select "form[action=?][method=post]", path do
      assert_select "input[name='linkedin_newsletter_draft[newsletter_name]'][value='Dev Notes']"
      assert_select "input[name='linkedin_newsletter_draft[title]'][value=?]", title
      assert_select "textarea[name='linkedin_newsletter_draft[body]']", text: "작성 중인 본문"
    end

    draft = @account.linkedin_newsletter_drafts.create!(title: "가상 초안")
    patch pd_profile_account_newsletter_draft_path(@account, draft), params: { linkedin_newsletter_draft: { title: "가" * 201 } }
    assert_response :unprocessable_entity
    assert_select "[role=alert] li"
    assert_equal "가상 초안", draft.reload.title
  end
end
