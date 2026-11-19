require "test_helper"

class MemberBookingSecurityTest < ActiveSupport::TestCase
  test "rejects javascript urls" do
    booking = MemberBooking.new(external_url: "javascript:alert(1)")
    booking.valid?
    assert booking.errors[:external_url].any?
  end
end
