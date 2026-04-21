class ProConsent < ApplicationRecord
  TYPES = %w[kakao_data_processing customer_disclosure tos].freeze

  validates :owner_id, :consent_type, presence: true
  validates :consent_type, inclusion: { in: TYPES }

  scope :for_owner, ->(oid) { where(owner_id: oid) }
  scope :granted, -> { where(consented: true).where(revoked_at: nil) }

  def revoke!
    update!(revoked_at: Time.current, consented: false)
  end

  def self.has_consent?(owner_id:, type:)
    granted.for_owner(owner_id).where(consent_type: type).exists?
  end
end
