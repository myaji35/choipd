require "test_helper"

class PublicPagesTest < ActionDispatch::IntegrationTest
  test "homepage returns 200" do
    get root_path
    assert_response :success
    assert_select "footer a[href=?]", new_inquiry_path, text: "문의하기"
    assert_select "a[href=?]", privacy_path, text: "개인정보처리방침", count: 1
  end

  test "inquiry page returns 200" do
    get new_inquiry_path
    assert_response :success
  end

  test "education page returns 200" do
    get education_path
    assert_response :success
  end

  test "media page returns 200" do
    get media_path
    assert_response :success
  end

  test "works page returns 200" do
    get works_path
    assert_response :success
  end

  test "community page returns 200" do
    get community_path
    assert_response :success
  end
end
