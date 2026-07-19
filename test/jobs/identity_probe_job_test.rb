# frozen_string_literal: true

require "test_helper"

class IdentityProbeJobTest < ActiveJob::TestCase
  setup do
    @member = Member.create!(
      tenant_id: 1,
      name: "박잡테스트",
      email: "probe-job-#{SecureRandom.hex(4)}@example.com",
      slug: "probe-job-#{SecureRandom.hex(4)}",
      business_type: "individual",
      profession: "custom",
      status: "approved",
      impd_status: "none",
    )
    # 실제 외부 호출 금지 — 모든 소스는 mock fallback.
    ENV["ANTHROPIC_API_KEY"] = nil
    ENV["GOOGLE_CSE_KEY"] = nil
    ENV["NAVER_CLIENT_ID"] = nil
  end

  test "perform_now creates an IdentityProbe record for the member" do
    assert_difference -> { IdentityProbe.where(member_id: @member.id).count }, 1 do
      IdentityProbeJob.perform_now(@member.id)
    end
  end

  test "perform_now completes with mock fallback when ANTHROPIC_API_KEY is blank" do
    IdentityProbeJob.perform_now(@member.id)
    probe = IdentityProbe.where(member_id: @member.id).order(created_at: :desc).first
    assert_not_nil probe
    assert_equal "completed", probe.status
  end

  test "perform_now on nonexistent member_id returns silently without raising" do
    assert_nothing_raised do
      IdentityProbeJob.perform_now(-1)
    end
    # Job must not create any probe for a missing member.
    assert_equal 0, IdentityProbe.where(member_id: -1).count
  end
end
