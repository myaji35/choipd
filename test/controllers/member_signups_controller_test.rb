# frozen_string_literal: true

require "test_helper"

class MemberSignupsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def valid_params(overrides = {})
    base = {
      name: "이가입",
      email: "signup-#{SecureRandom.hex(4)}@example.com",
      slug: "signup-#{SecureRandom.hex(4)}",
      password: "password1234",
      password_confirmation: "password1234",
      business_type: "individual",
      profession: "custom",
      region: "서울"
    }
    # terms_agree: 가입 필수 동의(ISS-116). member 밖 최상위 파라미터.
    { member: base.merge(overrides), terms_agree: "1" }
  end

  test "signup renders profession radio cards with custom selected" do
    get "/auth/signup"
    assert_response :success
    Member::PROFESSIONS.each do |profession|
      assert_select "input[type=radio][name='member[profession]'][value=?]", profession
    end
    assert_select "input[type=radio][value=custom][checked]"
    assert_select "label", text: /직접 입력\/기타/
  end

  test "signup accepts the selected profession" do
    params = valid_params(profession: "educator")
    post "/auth/signup", params: params
    assert_equal "educator", Member.find_by!(email: params[:member][:email]).profession
  end

  test "POST /auth/signup without consent checkbox goes to /<slug> and does not enqueue probe" do
    params = valid_params
    assert_no_enqueued_jobs only: IdentityProbeJob do
      assert_difference -> { Member.count }, 1 do
        post "/auth/signup", params: params
      end
    end

    member = Member.find_by(email: params[:member][:email])
    assert_not_nil member
    assert_redirected_to "/#{member.slug}"
    assert_nil member.identity_probe_consent_at
  end

  test "POST /auth/signup with consent checked redirects to /welcome/probe and enqueues IdentityProbeJob" do
    params = valid_params.merge(identity_probe_consent: "1")

    assert_enqueued_with(job: IdentityProbeJob) do
      assert_difference -> { Member.count }, 1 do
        post "/auth/signup", params: params
      end
    end

    member = Member.find_by(email: params[:member][:email])
    assert_not_nil member
    assert_not_nil member.identity_probe_consent_at
    assert_redirected_to "/welcome/probe"
  end
end
