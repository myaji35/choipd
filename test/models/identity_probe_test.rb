# frozen_string_literal: true

require "test_helper"

class IdentityProbeTest < ActiveSupport::TestCase
  def setup
    @member = Member.create!(
      tenant_id: 1,
      name: "김테스트",
      email: "probe-test-#{SecureRandom.hex(4)}@example.com",
      slug: "probe-m-#{SecureRandom.hex(4)}",
      business_type: "individual",
      profession: "custom",
      status: "approved",
      impd_status: "none",
    )
  end

  test "creating probe sets expires_at approximately +24h" do
    probe = IdentityProbe.create!(member: @member, status: "pending")
    assert_not_nil probe.expires_at
    delta = (probe.expires_at - Time.current).to_i
    # 24h = 86_400s. 허용 오차 ±60s.
    assert_in_delta 86_400, delta, 120, "expires_at should be ~24h from creation"
  end

  test "advance_step! updates last_step and merges step_payloads" do
    probe = IdentityProbe.create!(member: @member, status: "in_progress", step_payloads: {})
    probe.advance_step!(3, { foo: "bar" })
    assert_equal 3, probe.last_step
    assert_equal({ "foo" => "bar" }, probe.step_payloads["s3"])

    probe.advance_step!(4, { baz: "qux" })
    assert_equal 4, probe.last_step
    assert_equal({ "foo" => "bar" }, probe.step_payloads["s3"])
    assert_equal({ "baz" => "qux" }, probe.step_payloads["s4"])
  end

  test "finalize! accepted sets status completed and decided_at" do
    probe = IdentityProbe.create!(member: @member, status: "in_progress")
    probe.finalize!("accepted")
    assert_equal "completed", probe.status
    assert_equal "accepted", probe.user_decision
    assert_not_nil probe.decided_at
  end

  test "finalize! rejected sets status rejected" do
    probe = IdentityProbe.create!(member: @member, status: "in_progress")
    probe.finalize!("rejected")
    assert_equal "rejected", probe.status
    assert_equal "rejected", probe.user_decision
    assert_not_nil probe.decided_at
  end

  test "finalize! with invalid decision raises ArgumentError" do
    probe = IdentityProbe.create!(member: @member, status: "in_progress")
    assert_raises(ArgumentError) { probe.finalize!("maybe") }
  end

  test "purge_raw_signals! empties raw_signals and stamps raw_purged_at" do
    probe = IdentityProbe.create!(
      member: @member,
      status: "completed",
      raw_signals: [{ "source" => "gravatar", "data" => "secret" }],
    )
    assert_equal 1, probe.raw_signals.size
    probe.purge_raw_signals!
    assert_equal [], probe.raw_signals
    assert_not_nil probe.raw_purged_at
  end

  test "expired scope returns only rows with expires_at in past" do
    past = IdentityProbe.create!(member: @member, status: "pending")
    past.update_columns(expires_at: 1.hour.ago)

    future = IdentityProbe.create!(member: @member, status: "pending")
    future.update_columns(expires_at: 2.hours.from_now)

    ids = IdentityProbe.expired.pluck(:id)
    assert_includes ids, past.id
    assert_not_includes ids, future.id
  end

  test "validates status inclusion" do
    probe = IdentityProbe.new(member: @member, status: "bogus")
    assert_not probe.valid?
    assert_includes probe.errors[:status].join(" "), "not included"
  end

  test "validates user_decision inclusion when present" do
    probe = IdentityProbe.new(member: @member, status: "completed", user_decision: "meh")
    assert_not probe.valid?
    probe.user_decision = "accepted"
    assert probe.valid?
  end
end
