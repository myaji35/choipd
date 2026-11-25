require "test_helper"

class MemberAdminDashboardUxTest < ActionDispatch::IntegrationTest
  test "dashboard shows the next task and grouped navigation" do
    member = Member.create!(name: "테스트 회원", email: "dashboard-#{SecureRandom.hex(4)}@example.com", slug: "dashboard-#{SecureRandom.hex(4)}", status: "approved", business_type: "individual", profession: "custom", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: member.email, password: "password1234" }
    get slug_admin_dashboard_path(slug: member.slug)
    assert_response :success
    assert_includes response.body, "다음 할 일"
    assert_includes response.body, "전체 체크리스트"
    %w[내\ 페이지 고객 홍보].each { |heading| assert_includes response.body, heading }
    assert_not_includes response.body, "예시 페이지"
    assert_includes response.body, "아직 방문이 적어요"
  end

  test "SNS 팔로워 집계를 기다리는 이유와 숫자 띠 바로가기를 보여 준다" do
    slug = "dashboard-#{SecureRandom.hex(4)}"
    member = Member.create!(name: "테스트 회원", email: "#{slug}@example.com", slug: slug, status: "approved",
      business_type: "individual", password: "password1234", password_confirmation: "password1234")
    post "/auth/login", params: { email: member.email, password: "password1234" }

    get slug_admin_dashboard_path(slug: slug)

    assert_response :ok
    ["SNS 팔로워", "준비 중", "운영팀이 SNS 계정을 연결하면 보여요"].each do |text|
      assert_select ".dashboard-stats p", text: text
    end
    ["총 추종자", "최신 집계", "총합", "QR·공유 누적", "프로필 사진 업로드", "최근 수집", "등록 정보"].each do |text|
      assert_not_includes response.body, text
    end
    assert_select ".dashboard-stats a[href=?]", slug_admin_inquiries_path(slug: slug), text: "0"
    assert_select ".dashboard-stats a[href=?]", slug_admin_services_path(slug: slug), text: "0"
  end
end
