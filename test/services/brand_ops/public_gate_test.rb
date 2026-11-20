require "test_helper"

class BrandOps::PublicGateTest < ActiveSupport::TestCase
  setup do
    @old_env = %w[BRAND_OPS_MEMBERS_THRESHOLD BRAND_OPS_ACTIVE_MIN BRAND_OPS_COMMUNICATION_MIN].index_with { |key| ENV.delete(key) }
  end

  teardown do
    @old_env.each { |key, value| ENV[key] = value }
  end

  test "opens early even without activity" do
    status = gate_status(members_total: 8, members_active: 0)
    assert status[:open]
    assert_equal "early", status[:reason]
    assert_equal 8, status[:members_total]
    assert_equal 50, status[:members_threshold]
  end

  test "closes at threshold without activity" do
    status = gate_status(members_total: 50, members_active: 0)
    assert_not status[:open]
    assert_equal "criteria_not_met", status[:reason]
  end

  test "opens at threshold when criteria are met" do
    status = gate_status(members_total: 50, members_active: 5, inquiries: 10)
    assert status[:open]
    assert_equal "criteria_met", status[:reason]
  end

  test "member threshold can be overridden" do
    ENV["BRAND_OPS_MEMBERS_THRESHOLD"] = "0"
    status = gate_status(members_total: 8, members_active: 0)
    assert_not status[:open]
    assert_equal 0, status[:members_threshold]
  end

  private

  def gate_status(row)
    original = BrandOps::WeeklyStats.method(:platform)
    BrandOps::WeeklyStats.define_singleton_method(:platform) { |**| [ row ] }
    BrandOps::PublicGate.status
  ensure
    BrandOps::WeeklyStats.define_singleton_method(:platform, original)
  end
end
