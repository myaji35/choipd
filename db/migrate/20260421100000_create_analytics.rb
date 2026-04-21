class CreateAnalytics < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_events do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :user_id
      t.string :user_type      # admin | pd | distributor | lead | anonymous
      t.string :session_id
      t.string :event_name, null: false
      t.string :event_category, null: false
      t.string :event_action
      t.string :event_label
      t.integer :event_value
      t.string :page_path
      t.string :page_title
      t.string :referrer
      t.string :ip_address
      t.string :user_agent
      t.string :device_type    # desktop | mobile | tablet
      t.string :browser
      t.string :os
      t.string :country
      t.string :city
      t.text :metadata         # JSON
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :analytics_events, [:tenant_id, :created_at]
    add_index :analytics_events, :event_name
    add_index :analytics_events, :user_id

    create_table :cohorts do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :name, null: false
      t.text :description
      t.string :cohort_type, null: false   # acquisition | behavior | demographic | custom
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.text :criteria, null: false        # JSON
      t.integer :user_count, default: 0, null: false
      t.text :metrics                       # JSON
      t.string :created_by, null: false
      t.timestamps
    end
    add_index :cohorts, :tenant_id

    create_table :cohort_users do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :cohort, foreign_key: { on_delete: :cascade }, null: false
      t.string :user_id, null: false
      t.string :user_email
      t.datetime :joined_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
      t.text :metadata    # JSON
    end

    create_table :ab_tests do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :name, null: false
      t.text :description
      t.text :hypothesis
      t.string :status, default: "draft", null: false  # draft | running | paused | completed | archived
      t.datetime :start_date
      t.datetime :end_date
      t.string :target_metric, null: false
      t.text :variants, null: false               # JSON
      t.text :traffic_allocation, null: false      # JSON
      t.integer :total_participants, default: 0
      t.integer :confidence_level, default: 95
      t.text :results                              # JSON
      t.string :winner
      t.string :created_by, null: false
      t.timestamps
    end
    add_index :ab_tests, :tenant_id
    add_index :ab_tests, :status

    create_table :ab_test_participants do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :ab_test, foreign_key: { on_delete: :cascade }, null: false
      t.string :user_id
      t.string :session_id, null: false
      t.string :variant, null: false
      t.boolean :converted, default: false
      t.integer :conversion_value
      t.datetime :assigned_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
      t.datetime :converted_at
      t.text :metadata
    end
    add_index :ab_test_participants, :session_id
    add_index :ab_test_participants, [:ab_test_id, :variant]

    create_table :custom_reports do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :name, null: false
      t.text :description
      t.string :report_type, null: false   # table | chart | dashboard | export
      t.string :data_source, null: false
      t.text :columns, null: false         # JSON
      t.text :filters
      t.text :group_by
      t.text :order_by
      t.string :chart_type                 # line | bar | pie | area | scatter | heatmap
      t.text :chart_config
      t.text :schedule
      t.text :recipients
      t.boolean :is_public, default: false
      t.string :created_by, null: false
      t.timestamps
    end
    add_index :custom_reports, :tenant_id

    create_table :funnels do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :name, null: false
      t.text :description
      t.text :steps, null: false           # JSON: ["page_view", "signup", "payment"]
      t.integer :conversion_window, default: 7
      t.integer :total_users, default: 0
      t.text :conversion_data              # JSON: per-step conversion
      t.string :created_by, null: false
      t.timestamps
    end
    add_index :funnels, :tenant_id

    create_table :rfm_segments do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :user_id, null: false
      t.string :user_type, null: false     # distributor | lead
      t.integer :recency_score, null: false   # 1-5
      t.integer :frequency_score, null: false
      t.integer :monetary_score, null: false
      t.string :rfm_segment, null: false      # Champions | Loyal | At Risk | ...
      t.datetime :last_activity_at
      t.integer :total_transactions, default: 0
      t.integer :total_revenue, default: 0
      t.datetime :calculated_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :rfm_segments, :tenant_id
    add_index :rfm_segments, :rfm_segment
  end
end
