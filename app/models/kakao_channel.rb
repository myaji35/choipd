class KakaoChannel < ApplicationRecord
  has_many :kakao_messages, dependent: :destroy
  has_many :kakao_summaries, dependent: :destroy
  has_many :kakao_alerts, dependent: :destroy

  STATUSES = %w[pending connected revoked error].freeze

  validates :channel_id, presence: true, uniqueness: true
  validates :owner_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :for_owner, ->(oid) { where(owner_id: oid) }
  scope :connected, -> { where(status: "connected") }

  def connect!
    update!(status: "connected", connected_at: Time.current)
  end

  def revoke!
    update!(status: "revoked")
  end
end
