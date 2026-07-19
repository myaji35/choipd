# frozen_string_literal: true

require "test_helper"

class IdentityProbesControllerTest < ActionDispatch::IntegrationTest
  def sign_in_as(member)
    # MemberAuthController#create 경로를 사용해 session[:member_id]를 세팅.
    post "/auth/login", params: { email: member.email, password: "password1234" }
    # redirect_to "/#{slug}" 가능성 존재
    follow_redirect! if response.redirect?
  end

  setup do
    @member = Member.create!(
      tenant_id: 1,
      name: "정컨트롤러",
      email: "probe-ctrl-#{SecureRandom.hex(4)}@example.com",
      slug: "probe-ctrl-#{SecureRandom.hex(4)}",
      business_type: "individual",
      profession: "custom",
      status: "approved",
      impd_status: "none",
      password: "password1234",
      password_confirmation: "password1234",
      identity_probe_consent_at: Time.current,
    )
  end

  test "GET /welcome/probe without login redirects to /auth/login" do
    get "/welcome/probe"
    assert_response :redirect
    assert_redirected_to member_login_path
  end

  test "GET /welcome/probe with signed-in member and completed probe renders 200" do
    sign_in_as(@member)
    IdentityProbe.create!(
      member: @member,
      status: "completed",
      last_step: 0,
      identity: { "profile" => { "display_name" => @member.name, "confidence" => 0.8 }, "structured" => {} },
      sources_queried: %w[gravatar google],
      sources_hit: %w[gravatar],
      raw_signals: [],
      step_payloads: {},
    )

    get "/welcome/probe"
    assert_response :success
    assert_match(/PROBE/i, response.body)
  end

  test "GET /welcome/probe/status returns JSON {status, last_step, progress_percent}" do
    sign_in_as(@member)
    IdentityProbe.create!(
      member: @member,
      status: "in_progress",
      last_step: 0,
      sources_queried: ["gravatar"],
      sources_hit: [],
      raw_signals: [],
      step_payloads: {},
    )

    get "/welcome/probe/status"
    assert_response :success
    body = JSON.parse(response.body)
    assert body.key?("status")
    assert body.key?("last_step")
    assert body.key?("progress_percent")
  end

  test "PATCH /welcome/probe/step/2 advances last_step and saves step_payloads" do
    sign_in_as(@member)
    probe = IdentityProbe.create!(
      member: @member,
      status: "completed",
      last_step: 1,
      identity: {},
      step_payloads: {},
    )

    patch "/welcome/probe/step/2", params: { payload: { profession: "강사" } }
    assert_response :redirect

    probe.reload
    assert_equal 2, probe.last_step
    assert_equal({ "profession" => "강사" }, probe.step_payloads["s2"])
  end

  test "POST /welcome/probe/finish with both required consents applies to member and redirects to slug" do
    sign_in_as(@member)
    probe = IdentityProbe.create!(
      member: @member,
      status: "completed",
      last_step: 4,
      identity: {},
      step_payloads: { "s4" => { "bio" => "새 소개 문장" } },
    )

    post "/welcome/probe/finish", params: { consents: { publish: "1", share: "1" } }
    assert_response :redirect
    assert_redirected_to "/#{@member.slug}"

    probe.reload
    assert_equal "completed", probe.status
    assert_equal "accepted", probe.user_decision

    @member.reload
    assert_equal "새 소개 문장", @member.bio
  end

  test "POST /welcome/probe/finish without required consents redirects back with error flag" do
    sign_in_as(@member)
    IdentityProbe.create!(
      member: @member,
      status: "completed",
      last_step: 6,
      identity: {},
      step_payloads: {},
    )

    post "/welcome/probe/finish", params: { consents: { publish: "0", share: "0" } }
    assert_response :redirect
    assert_includes response.location, "error=required_consent_missing"
  end

  test "POST /welcome/probe/skip sets status rejected and redirects to slug" do
    sign_in_as(@member)
    probe = IdentityProbe.create!(
      member: @member,
      status: "in_progress",
      last_step: 0,
      step_payloads: {},
    )

    post "/welcome/probe/skip"
    assert_response :redirect
    assert_redirected_to "/#{@member.slug}"

    probe.reload
    assert_equal "rejected", probe.status
    assert_equal "rejected", probe.user_decision
  end
end
