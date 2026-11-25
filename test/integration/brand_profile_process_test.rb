require "test_helper"
require "rake"

class BrandProfileProcessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "승인 시 개인 브랜드를 생성하고 다시 활성화해도 기존 브랜드를 유지한다" do
    sign_in staff("admin")
    member = create_member(status: "pending_approval")
    existing = member.brands.create!(name: "기존 브랜드")

    assert_difference -> { member.brands.where(personal: true).count }, 1 do
      post approve_admin_member_path(member)
    end
    assert_redirected_to admin_member_path(member)
    assert member.reload.approved?
    brand = member.personal_brand
    assert_equal [ member.name, member.profession_label, member.region, false ],
      [ brand.name, brand.business_type, brand.region, brand.published? ]
    assert_not existing.reload.personal?

    assert_no_difference -> { member.brands.count } do
      post activate_admin_member_path(member)
    end
    assert_redirected_to admin_member_path(member)
    assert_equal brand, member.personal_brand
  end

  test "개인 브랜드 생성에 실패해도 회원 승인을 저장한다" do
    sign_in staff("admin")
    member = create_member(status: "pending_approval")
    original_create = Brand.method(:create!)
    Brand.define_singleton_method(:create!) { |**| raise ActiveRecord::RecordNotUnique, "브랜드 생성 실패" }

    post approve_admin_member_path(member)

    assert_redirected_to admin_member_path(member)
    assert_equal "approved", member.reload.status
    assert_equal "#{member.name} 승인 완료 (개인 브랜드는 회원 상세에서 다시 만들어 주세요)", flash[:notice]
  ensure
    Brand.define_singleton_method(:create!, original_create) if original_create
  end

  test "운영자 회원 상세에서 브랜드를 만들고 연결된 프로필 계정을 볼 수 있다" do
    sign_in staff("admin")
    member = create_member
    brand = member.brands.create!(name: "기존 브랜드")

    get admin_member_path(member)
    assert_response :success
    assert_select "h2", text: "브랜드"
    assert_select "h2", text: "프로필 계정(네이버 인물정보·LinkedIn)"
    assert_select "a[href=?]", admin_brand_path(brand), text: brand.name
    assert_select "a[href=?]", new_pd_profile_account_path(member_id: member.id), text: "계정 추가"
    assert_select "p", text: "연결된 프로필 계정이 없습니다."
    assert_select "form[method=post][action=?] button", create_personal_brand_admin_member_path(member), text: "개인 브랜드 만들기"

    post create_personal_brand_admin_member_path(member)
    assert_redirected_to admin_member_path(member)
    account = member.profile_accounts.create!(platform: "linkedin", display_name: "테스트 프로필")
    follow_redirect!
    assert_select "a[href=?]", pd_profile_account_path(account), text: "LinkedIn · 테스트 프로필"
    assert_select "li span", text: account.session_status_label
    assert_select "li span", text: "개인(기본)"
    assert_select "button", text: "개인 브랜드 만들기", count: 0
  end

  test "회원 홍보 메뉴에서 발행 링크를 빼고 기존 화면에 이전 안내를 표시한다" do
    member = create_member
    sign_in_member(member)
    slug = member.slug

    get slug_admin_dashboard_path(slug:)
    assert_response :success
    [ slug_admin_sns_accounts_path(slug:), slug_admin_scheduled_posts_path(slug:) ].each do |path|
      assert_select ".admin-nav a[href=?], aside a[href=?]", path, path, count: 0
    end

    [ slug_admin_sns_accounts_path(slug:), slug_admin_scheduled_posts_path(slug:) ].each do |path|
      get path
      assert_response :success
      assert_select "p", text: "SNS 채널 운영은 SocialDoctors 로 옮겨졌습니다. 이미 예약된 발행은 그대로 진행됩니다. 새 채널 연결·발행은 운영팀이 SocialDoctors 에서 맡습니다."
      assert_select "a[href=?]", slug_admin_brand_path(slug:), text: "내 브랜드로 가기"
    end
  end

  test "회원 브랜드 화면에 개인 브랜드가 먼저 나오고 관리자 핸드오프가 노출되지 않는다" do
    member = create_member
    member.brands.create!(name: "A 기존 브랜드")
    brand = member.ensure_personal_brand!
    brand.update!(website_url: "https://example.test")
    sign_in_member(member)
    previous_secret = ENV["IMPD_HANDOFF_SECRET"]
    ENV["IMPD_HANDOFF_SECRET"] = "test-handoff-secret"

    get slug_admin_brand_path(slug: member.slug)
    assert_response :success
    assert_select "h2", text: "내 정보가 실리는 곳"
    assert_select "h2", text: "채널 운영", count: 0
    assert_select "article.impd-card:first-child h3", text: /#{Regexp.escape(member.name)}.*개인\(기본\)/m
    assert_not_includes response.body, "/api/admin/handoff"
  ensure
    ENV["IMPD_HANDOFF_SECRET"] = previous_secret
  end

  test "개인 브랜드 생성 작업은 기본 실행에서 대상 회원만 집계한다" do
    previous_apply = ENV.delete("APPLY")
    candidate = create_member
    excluded = [ create_member(status: "pending_approval"), create_member(withdrawn_at: Time.current) ]
    with_brand = create_member
    with_brand.ensure_personal_brand!
    task = Rake::Task.task_defined?("brands:ensure_personal") ? Rake::Task["brands:ensure_personal"] : nil
    unless task
      Rails.application.load_tasks
      task = Rake::Task["brands:ensure_personal"]
    end

    output = nil
    assert_no_difference "Brand.count" do
      output, = capture_io { task.invoke }
    end
    assert_includes output.lines.map(&:strip), candidate.id.to_s
    (excluded + [ with_brand ]).each do |member|
      assert_not_includes output.lines.map(&:strip), member.id.to_s
    end
    assert_match(/DRY_RUN: \d+건/, output)
  ensure
    task&.reenable
    ENV["APPLY"] = previous_apply
  end

  test "PD가 새 계정 화면에서 회원을 미리 선택하고 저장할 수 있다" do
    sign_in staff("pd")
    member = create_member
    pending = create_member(status: "pending_approval")

    get new_pd_profile_account_path(member_id: member.id)
    assert_response :success
    assert_select "select[name='profile_account[member_id]']" do
      assert_select "option[selected][value=?]", member.id.to_s, text: "#{member.name} (#{member.slug})"
      assert_select "option[value='']", text: "연결 안 함"
      assert_select "option[value=?]", pending.id.to_s, count: 0
    end

    post pd_profile_accounts_path, params: { profile_account: { member_id: member.id, platform: "linkedin", display_name: "회원 프로필" } }
    assert_redirected_to pd_member_path(member, anchor: "accounts")
    get pd_profile_accounts_path
    assert_select "td", text: member.name
  end

  test "PD 새 계정 화면과 저장 실패 화면에서 승인 대기 회원을 선택한 상태로 표시한다" do
    sign_in staff("pd")
    member = create_member(status: "pending_approval")
    selector = "select[name='profile_account[member_id]'] option[selected][value=?]"

    get new_pd_profile_account_path(member_id: member.id)
    assert_response :success
    assert_select selector, member.id.to_s, text: "#{member.name} (승인 대기)"

    post pd_profile_accounts_path, params: { profile_account: { member_id: member.id, platform: "linkedin" } }
    assert_response :unprocessable_entity
    assert_select selector, member.id.to_s, text: "#{member.name} (승인 대기)"
  end

  private

  def staff(role)
    AdminUser.create!(email: "#{role}-#{SecureRandom.hex(4)}@example.test", password: "password123", role: role)
  end

  def create_member(**attributes)
    slug = "brand-process-#{SecureRandom.hex(4)}"
    Member.create!(
      name: "회원 #{slug}", email: "#{slug}@example.test", slug: slug,
      status: "approved", business_type: "individual", profession: "author", region: "서울",
      password: "password1234", **attributes
    )
  end

  def sign_in_member(member)
    post "/auth/login", params: { email: member.email, password: "password1234" }
  end
end
