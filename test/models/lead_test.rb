require "test_helper"

class LeadTest < ActiveSupport::TestCase
  test "creates lead with valid email" do
    lead = Lead.new(email: "subscriber@example.com", tenant_id: 1)
    assert lead.save
    assert_not_nil lead.subscribed_at
  end

  test "rejects invalid email" do
    lead = Lead.new(email: "not-email", tenant_id: 1)
    assert_not lead.valid?
  end

  test "tenant + email is unique" do
    Lead.create!(email: "dup@example.com", tenant_id: 1)
    duplicate = Lead.new(email: "dup@example.com", tenant_id: 1)
    assert_not duplicate.valid?
  end

  test "same email in different tenant allowed" do
    Lead.create!(email: "shared@example.com", tenant_id: 1)
    other = Lead.new(email: "shared@example.com", tenant_id: 2)
    assert other.valid?
  end
end
