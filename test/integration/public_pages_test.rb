require "test_helper"

class PublicPagesTest < ActionDispatch::IntegrationTest
  test "homepage returns 200" do
    get root_path
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
