require "test_helper"

class ProConsentTest < ActiveSupport::TestCase
  test "brand consent types can be granted and revoked without deleting history" do
    %w[socialdoctors_exposure townin_local_ads].each do |type|
      consent = ProConsent.create!(owner_id: "876543", consent_type: type, consented: true, consented_at: Time.current)
      assert_equal consent, ProConsent.current_for("876543", type)
      consent.revoke!
      assert_nil ProConsent.current_for("876543", type)
      assert consent.reload.revoked_at
    end
  end

  test "current_for selects latest grant" do
    old = ProConsent.create!(owner_id: "876543", consent_type: "socialdoctors_exposure", consented: true, consented_at: 1.day.ago)
    recent = ProConsent.create!(owner_id: "876543", consent_type: old.consent_type, consented: true, consented_at: Time.current)
    assert_equal recent, ProConsent.current_for("876543", old.consent_type)
  end
end
