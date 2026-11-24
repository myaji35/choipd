require "test_helper"

class Pd::ProfileAccountLinkedinPostsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = AdminUser.create!(email: "linkedin-posts@example.test", password: "password123", role: "pd")
    sign_in @admin
    @account = ProfileAccount.create!(platform: "linkedin", display_name: "공유 계정", tenant_id: 2)
    @return_path = pd_profile_account_path(@account, anchor: "linkedin-posts")
  end

  test "creates a draft with defaults and edits its message and time" do
    freeze_time do
      post pd_profile_account_linkedin_posts_path(@account), params: {
        sns_scheduled_post: { message: "새 초안", scheduled_at: "", status: "scheduled", approved_at: Time.current }
      }
      assert_redirected_to @return_path
      record = @account.linkedin_share_posts.sole
      assert_equal [ "linkedin", 2, "draft", Time.current, nil ],
        [ record.platform, record.tenant_id, record.status, record.scheduled_at, record.approved_at ]

      get edit_pd_profile_account_linkedin_post_path(@account, record)
      assert_response :success
      assert_select "textarea", text: "새 초안"

      patch pd_profile_account_linkedin_post_path(@account, record), params: {
        sns_scheduled_post: { message: "수정 초안", scheduled_at: "2027-01-01T12:00" }
      }
      assert_redirected_to @return_path
      assert_equal "수정 초안", record.reload.message
      assert_equal Time.utc(2027, 1, 1, 3), record.scheduled_at
    end
  end

  test "rejects access via another account and rejects Naver accounts" do
    other = ProfileAccount.create!(platform: "linkedin", display_name: "다른 계정")
    record = create_draft
    get edit_pd_profile_account_linkedin_post_path(other, record)
    assert_response :not_found

    sign_in @admin
    naver = ProfileAccount.create!(platform: "naver_people", display_name: "네이버 계정")
    assert_no_difference "SnsScheduledPost.count" do
      post pd_profile_account_linkedin_posts_path(naver), params: { sns_scheduled_post: { message: "초안" } }
    end
    assert_redirected_to pd_profile_account_path(naver)
    assert flash[:alert].present?
  end

  test "approving a due draft twice publishes once and locks it for editing" do
    record = create_draft
    url = "https://www.linkedin.com/feed/update/urn:li:activity:42/"
    calls = []
    execute = lambda do |**payload|
      calls << payload
      assert record.reload.status_publishing?
      assert record.approved_at?
      { "ok" => true, "url" => url }
    end

    with_publisher(execute) do
      2.times do
        patch approve_pd_profile_account_linkedin_post_path(@account, record)
        assert_redirected_to @return_path
      end
    end
    assert_equal [ { kind: "post", account: @account, text: "초안" } ], calls
    assert record.reload.status_published?
    assert_equal url, record.published_url
    follow_redirect!
    assert_select "a[href=?][target=_blank][rel=noopener]", url

    get edit_pd_profile_account_linkedin_post_path(@account, record)
    assert_redirected_to @return_path
    patch pd_profile_account_linkedin_post_path(@account, record), params: { sns_scheduled_post: { message: "수정" } }
    assert_redirected_to @return_path
    assert_equal "초안", record.reload.message
  end

  test "future approval waits and can be canceled without invoking the publisher" do
    record = create_draft(scheduled_at: 1.day.from_now)
    with_publisher(->(**) { flunk "unexpected publishing" }) do
      patch approve_pd_profile_account_linkedin_post_path(@account, record)
      assert_redirected_to @return_path
      assert_match(/예약 시각.*게시됩니다/, flash[:notice])
      assert record.reload.status_scheduled?
      assert record.approved_at?

      patch unapprove_pd_profile_account_linkedin_post_path(@account, record)
      assert_redirected_to @return_path
    end
    assert record.reload.status_draft?
    assert_nil record.approved_at
  end

  private

  def create_draft(scheduled_at: 1.minute.ago)
    @account.linkedin_share_posts.create!(platform: "linkedin", message: "초안", scheduled_at: scheduled_at, status: "draft")
  end

  def with_publisher(execute)
    publisher = Object.new
    publisher.define_singleton_method(:call) { |**payload| execute.call(**payload) }
    original = EgoProfile::LinkedinPublisher.method(:new)
    EgoProfile::LinkedinPublisher.define_singleton_method(:new) { publisher }
    yield
  ensure
    EgoProfile::LinkedinPublisher.define_singleton_method(:new, original)
  end
end
