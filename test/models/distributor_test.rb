require "test_helper"

class DistributorTest < ActiveSupport::TestCase
  def setup
    @distributor = Distributor.create!(
      name: "Test Dist",
      email: "test@example.com",
      business_type: "retail",
      tenant_id: 1,
      status: "pending"
    )
  end

  test "approve! changes status to approved and sets approved_at" do
    @distributor.approve!
    assert_equal "approved", @distributor.status
    assert_not_nil @distributor.approved_at
    assert_equal 1, @distributor.distributor_activity_logs.count
  end

  test "reject! changes status to rejected with reason" do
    @distributor.reject!(reason: "incomplete docs")
    assert_equal "rejected", @distributor.status
    log = @distributor.distributor_activity_logs.last
    assert_includes log.description, "incomplete docs"
  end

  test "suspend! and activate! state transitions" do
    @distributor.approve!
    @distributor.suspend!(reason: "violation")
    assert_equal "suspended", @distributor.status

    @distributor.activate!
    assert_equal "approved", @distributor.status
  end

  test "validates email format" do
    invalid = Distributor.new(name: "X", email: "not-an-email", business_type: "etc")
    assert_not invalid.valid?
    assert_includes invalid.errors[:email].join(" "), "is invalid"
  end

  test "for_tenant scope filters by tenant_id" do
    Distributor.create!(name: "T2", email: "t2@example.com", business_type: "retail", tenant_id: 2)
    assert_equal 1, Distributor.for_tenant(1).count
    assert_equal 1, Distributor.for_tenant(2).count
  end
end
