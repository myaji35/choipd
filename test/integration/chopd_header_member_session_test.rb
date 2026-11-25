require "test_helper"

class ChopdHeaderMemberSessionTest < ActionDispatch::IntegrationTest
  test "로그인 전에는 데스크톱과 모바일 헤더에 가입과 로그인 링크가 표시된다" do
    get education_path
    assert_response :ok

    assert_guest_header
  end

  test "로그인 후에는 데스크톱과 모바일 헤더에 내 페이지와 로그아웃이 표시된다" do
    member = sign_in_member

    get education_path
    assert_response :ok

    [ ".nav-cta-wrap", "#mobile-nav" ].each do |navigation|
      assert_select navigation, count: 1 do
        assert_select "a", text: "내 페이지", count: 1 do |links|
          assert_equal "/#{member.slug}", links.first["href"]
        end
        assert_select "form[action=?]", member_logout_path, count: 1 do |forms|
          assert_equal "로그아웃하시겠습니까?", forms.first["data-turbo-confirm"]
          assert_select "input[name='_method'][value='delete']", count: 1
        end
        assert_select "a[href=?]", member_signup_path, count: 0
        assert_select "a[href=?]", member_login_path, count: 0
      end
    end
    assert_select ".nav-cta-wrap .nav-session-name", text: member.name, count: 1

    get "/#{member.slug}"
    assert_response :ok
  end

  test "로그아웃 후에는 회원 세션이 지워지고 헤더에 가입과 로그인 링크가 다시 표시된다" do
    sign_in_member

    delete member_logout_path
    assert_redirected_to root_path
    assert_nil request.session[:member_id]

    get education_path
    assert_response :ok
    assert_guest_header
  end

  private

  def sign_in_member
    member = Member.create!(
      name: "헤더 테스트 회원",
      email: "chopd-header@example.test",
      slug: "chopd-header-member",
      status: "approved",
      business_type: "individual",
      profession: "custom",
      password: "password1234"
    )
    post member_login_path, params: { email: member.email, password: "password1234" }
    assert_equal member.id, request.session[:member_id]
    member
  end

  def assert_guest_header
    [ ".nav-cta-wrap", "#mobile-nav" ].each do |navigation|
      assert_select navigation, count: 1 do
        assert_select "a[href=?]", member_signup_path, text: "회원가입", count: 1
        assert_select "a[href=?]", member_login_path, text: "로그인", count: 1
        assert_select "a", text: "내 페이지", count: 0
        assert_select "form[action=?]", member_logout_path, count: 0
      end
    end
  end
end
