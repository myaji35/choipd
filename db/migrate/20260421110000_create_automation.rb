class CreateAutomation < ActiveRecord::Migration[8.1]
  def change
    create_table :workflows do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :name, null: false
      t.text :description
      t.string :trigger, null: false              # manual | schedule | event | webhook
      t.text :trigger_config, null: false         # JSON
      t.text :actions, null: false                # JSON
      t.boolean :is_active, default: true, null: false
      t.string :created_by, null: false
      t.datetime :last_executed_at
      t.integer :execution_count, default: 0, null: false
      t.integer :success_count, default: 0, null: false
      t.integer :failure_count, default: 0, null: false
      t.timestamps
    end
    add_index :workflows, :tenant_id

    create_table :workflow_executions do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :workflow, foreign_key: { on_delete: :cascade }, null: false
      t.string :status, default: "pending", null: false   # pending | running | completed | failed | cancelled
      t.string :trigger, null: false
      t.text :trigger_data
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :duration                                  # ms
      t.text :steps
      t.text :error
      t.text :metadata
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :workflow_executions, [:workflow_id, :created_at]

    create_table :integrations do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :name, null: false                          # Slack | Discord | Google Sheets | ...
      t.string :type_name, null: false                     # messaging | crm | storage | analytics | automation
      t.string :provider, null: false                      # slack | discord | google | ...
      t.boolean :is_enabled, default: true, null: false
      t.text :credentials, null: false                     # JSON (encrypted)
      t.text :config
      t.text :scopes
      t.string :webhook_url
      t.datetime :last_synced_at
      t.string :sync_status, default: "active"             # active | error | disabled
      t.text :error_message
      t.string :created_by, null: false
      t.timestamps
    end
    add_index :integrations, :tenant_id
    add_index :integrations, :provider

    create_table :webhooks do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :name, null: false
      t.string :url, null: false
      t.text :events, null: false                          # JSON
      t.string :secret, null: false                        # HMAC
      t.boolean :is_active, default: true, null: false
      t.text :headers
      t.text :retry_config
      t.datetime :last_triggered_at
      t.integer :success_count, default: 0, null: false
      t.integer :failure_count, default: 0, null: false
      t.string :created_by, null: false
      t.timestamps
    end
    add_index :webhooks, :tenant_id

    create_table :webhook_logs do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :webhook, foreign_key: { on_delete: :cascade }, null: false
      t.string :event, null: false
      t.text :payload, null: false
      t.string :status, null: false                        # success | failed | retrying
      t.integer :response_code
      t.text :response_body
      t.integer :attempt_number, default: 1, null: false
      t.text :error
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :webhook_logs, [:webhook_id, :created_at]

    create_table :automation_templates do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :name, null: false
      t.text :description, null: false
      t.string :category, null: false                      # onboarding | engagement | support | marketing | sales
      t.string :icon, default: "zap"
      t.text :workflow_template, null: false               # JSON
      t.text :required_integrations
      t.string :difficulty, default: "beginner", null: false # beginner | intermediate | advanced
      t.integer :estimated_time
      t.integer :popularity, default: 0, null: false
      t.boolean :is_public, default: true, null: false
      t.string :created_by, null: false
      t.timestamps
    end
    add_index :automation_templates, :tenant_id
    add_index :automation_templates, :category
  end
end
