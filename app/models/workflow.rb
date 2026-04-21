class Workflow < ApplicationRecord
  has_many :workflow_executions, dependent: :destroy

  TRIGGERS = %w[manual schedule event webhook].freeze

  validates :name, :trigger, :trigger_config, :actions, :created_by, presence: true
  validates :trigger, inclusion: { in: TRIGGERS }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :active, -> { where(is_active: true) }
  scope :recent, -> { order(updated_at: :desc) }

  def trigger_config_hash
    JSON.parse(trigger_config || "{}") rescue {}
  end

  def actions_list
    JSON.parse(actions || "[]") rescue []
  end

  # 워크플로우 실행 (간단 동기 — 실제는 Solid Queue로 백그라운드)
  def execute!(trigger_source: "manual", trigger_data: nil)
    exec = workflow_executions.create!(
      tenant_id: tenant_id,
      status: "running",
      trigger: trigger_source,
      trigger_data: trigger_data&.to_json,
      started_at: Time.current
    )
    begin
      results = actions_list.map { |a| run_action(a, exec) }
      exec.update!(
        status: "completed",
        completed_at: Time.current,
        duration: ((Time.current - exec.started_at) * 1000).to_i,
        steps: results.to_json
      )
      increment!(:execution_count)
      increment!(:success_count)
      update_column(:last_executed_at, Time.current)
    rescue StandardError => e
      exec.update!(status: "failed", completed_at: Time.current, error: e.message)
      increment!(:execution_count)
      increment!(:failure_count)
      raise
    end
    exec
  end

  private

  # 실제 액션 실행 — 단순화된 구현 (메일/웹훅/로그 등)
  def run_action(action, exec)
    type = action["type"] || action[:type]
    case type
    when "log"
      Rails.logger.info "[Workflow] #{name} → log: #{action['message']}"
      { type: type, status: "completed", output: action["message"] }
    when "webhook"
      uri = URI(action["url"])
      Net::HTTP.post(uri, action["payload"].to_json, "Content-Type" => "application/json")
      { type: type, status: "completed", url: action["url"] }
    when "wait"
      sleep((action["seconds"] || 1).to_i)
      { type: type, status: "completed" }
    else
      { type: type, status: "skipped", reason: "unknown action type" }
    end
  end
end
