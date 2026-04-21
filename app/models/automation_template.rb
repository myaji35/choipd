class AutomationTemplate < ApplicationRecord
  CATEGORIES = %w[onboarding engagement support marketing sales].freeze
  DIFFICULTIES = %w[beginner intermediate advanced].freeze

  validates :name, :description, :category, :workflow_template, :created_by, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :difficulty, inclusion: { in: DIFFICULTIES }

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }
  scope :public_visible, -> { where(is_public: true) }
  scope :popular, -> { order(popularity: :desc) }
  scope :by_category, ->(c) { where(category: c) if c.present? }

  def template_hash
    JSON.parse(workflow_template || "{}") rescue {}
  end

  def required_integrations_list
    JSON.parse(required_integrations || "[]") rescue []
  end

  # 템플릿으로 새 워크플로우 생성
  def instantiate!(created_by:)
    tpl = template_hash
    Workflow.create!(
      tenant_id: tenant_id,
      name: tpl["name"] || name,
      description: tpl["description"] || description,
      trigger: tpl["trigger"] || "manual",
      trigger_config: (tpl["trigger_config"] || {}).to_json,
      actions: (tpl["actions"] || []).to_json,
      created_by: created_by
    )
  end
end
