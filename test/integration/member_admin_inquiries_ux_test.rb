require "test_helper"

class MemberAdminInquiriesUxTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_member
    post "/auth/login", params: { email: @member.email, password: "password1234" }
    @inquiries_path = slug_admin_inquiries_path(slug: @member.slug)
  end

  test "새 문의와 확인한 문의를 구분하고 한국 시간을 보여 준다" do
    unread = create_inquiry(is_read: 0)
    read = create_inquiry(is_read: 1)

    get @inquiries_path

    assert_response :ok
    %w[INBOX 안읽음 November].each { |word| assert_not_includes response.body, word }
    assert_select "header span", text: "새 문의 1건"
    assert_select "section[aria-labelledby='new-inquiries-title'] h2", text: "새 문의 1건"
    assert_select "section[aria-labelledby='read-inquiries-title'] h2", text: "확인한 문의 1건"
    assert_select "article#inquiry-#{unread.id}" do
      assert_select "time", text: "2026.11.03 03:00"
      assert_select "span", text: "새 문의"
      assert_select "a.impd-btn-primary", text: "메일로 답장"
      assert_select "button", text: "확인했어요"
    end
    assert_includes response.body, "grid-template-columns: minmax(72px, max-content) minmax(0, 1fr) auto"
    assert_not_includes response.body, "minmax(0, 1fr) minmax(0, 2fr) auto"
    assert_select "details.inquiry-read#inquiry-#{read.id}:not([open])" do
      assert_select "summary strong", text: read.sender_name
      assert_select "summary time", text: "2026.11.03"
      assert_select "a.impd-btn-secondary", text: "메일로 답장"
      assert_select "button", text: "다시 새 문의로"
    end
  end

  test "모든 문의를 확인했으면 머리말에 새 문의 수가 없다" do
    create_inquiry(is_read: 1)

    get @inquiries_path

    assert_response :ok
    assert_includes response.body, "새 문의는 없어요. 문의가 오면 여기에 먼저 보여요."
    assert_no_match(/새 문의 \d+건/, response.body)
  end

  test "문의가 없으면 내 페이지 공유를 안내한다" do
    get @inquiries_path

    assert_response :ok
    assert_includes response.body, "아직 받은 문의가 없어요"
    assert_includes response.body, "내 페이지 주소를 고객에게 보내면 여기로 문의가 들어와요."
  end

  test "문의 상태를 바꾸면 이동한 위치와 알림을 보여 준다" do
    inquiry = create_inquiry(is_read: 0)
    path = toggle_read_slug_admin_inquiry_path(slug: @member.slug, id: inquiry)

    post path
    assert_redirected_to @inquiries_path
    follow_redirect!

    assert_select "[role=status]", text: /확인한 문의로 옮겼어요\./
    assert_select "details.inquiry-read.is-just-saved[open]", count: 1 do
      assert_select ".impd-just-saved-tag", text: "방금 옮김"
    end

    post path
    assert_redirected_to @inquiries_path
    follow_redirect!

    assert_select "[role=status]", text: /새 문의로 되돌렸어요\./
    assert_select "article.is-just-saved#inquiry-#{inquiry.id}", count: 1
  end

  private

  def create_inquiry(is_read:)
    @member.member_inquiries.create!(sender_name: "상담 고객", sender_email: "customer@example.com",
      message: "상담 일정을 알고 싶어요.", is_read: is_read, created_at: Time.utc(2026, 11, 2, 18, 0))
  end

  def create_member
    slug = "inquiries-ux-#{SecureRandom.hex(4)}"
    Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug, status: "approved",
      business_type: "individual", password: "password1234", password_confirmation: "password1234")
  end
end
