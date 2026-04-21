class Integration < ApplicationRecord
  TYPES = %w[messaging crm storage analytics automation].freeze
  PROVIDERS = %w[slack discord google hubspot zapier email sms].freeze
  SYNC_STATUSES = %w[active error disabled].freeze

  validates :name, :provider, :credentials, :created_by, presence: true
  validates :type_name, inclusion: { in: TYPES }, presence: true
  validates :sync_status, inclusion: { in: SYNC_STATUSES }, allow_nil: true

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :enabled, -> { where(is_enabled: true) }

  def credentials_hash
    JSON.parse(credentials || "{}") rescue {}
  end

  def config_hash
    JSON.parse(config || "{}") rescue {}
  end

  # 연결 테스트 (provider별 구현 필요. 현재는 stub)
  def test_connection!
    update!(last_synced_at: Time.current, sync_status: "active", error_message: nil)
    { success: true, message: "#{provider} 연결 정상" }
  rescue StandardError => e
    update!(sync_status: "error", error_message: e.message)
    { success: false, message: e.message }
  end
end
