class AlignKanbanWithNextjs < ActiveRecord::Migration[8.1]
  def change
    # tenant_id + 부속 컬럼 추가
    add_column :kanban_projects, :tenant_id, :integer, default: 1, null: false unless column_exists?(:kanban_projects, :tenant_id)
    add_column :kanban_projects, :icon, :string, default: "folder" unless column_exists?(:kanban_projects, :icon)
    add_column :kanban_projects, :is_archived, :boolean, default: false unless column_exists?(:kanban_projects, :is_archived)
    add_column :kanban_projects, :sort_order, :integer, default: 0 unless column_exists?(:kanban_projects, :sort_order)
    add_index  :kanban_projects, :tenant_id unless index_exists?(:kanban_projects, :tenant_id)

    add_column :kanban_columns, :tenant_id, :integer, default: 1, null: false unless column_exists?(:kanban_columns, :tenant_id)
    # column에 project_id 직접 — Rails는 kanban_project_id로 이미 있음, Next.js와 호환을 위해 project_id alias 추가
    add_column :kanban_columns, :color, :string, default: "#6b7280" unless column_exists?(:kanban_columns, :color)
    rename_column :kanban_columns, :position, :sort_order if column_exists?(:kanban_columns, :position) && !column_exists?(:kanban_columns, :sort_order)
    add_index  :kanban_columns, :tenant_id unless index_exists?(:kanban_columns, :tenant_id)

    add_column :kanban_tasks, :tenant_id, :integer, default: 1, null: false unless column_exists?(:kanban_tasks, :tenant_id)
    # tasks는 column_id만 있음, project_id 추가 (Next.js 호환)
    add_column :kanban_tasks, :project_id, :integer unless column_exists?(:kanban_tasks, :project_id)
    add_column :kanban_tasks, :assignee, :string unless column_exists?(:kanban_tasks, :assignee)
    add_column :kanban_tasks, :is_completed, :boolean, default: false unless column_exists?(:kanban_tasks, :is_completed)
    add_column :kanban_tasks, :completed_at, :datetime unless column_exists?(:kanban_tasks, :completed_at)
    rename_column :kanban_tasks, :position, :sort_order if column_exists?(:kanban_tasks, :position) && !column_exists?(:kanban_tasks, :sort_order)
    add_index  :kanban_tasks, :tenant_id unless index_exists?(:kanban_tasks, :tenant_id)
    add_index  :kanban_tasks, :project_id unless index_exists?(:kanban_tasks, :project_id)

    # ── notifications 테이블 (Phase 1에서 누락) ────────
    unless table_exists?(:notifications)
      create_table :notifications do |t|
        t.integer :tenant_id, default: 1, null: false
        t.integer :user_id
        t.string :title, null: false
        t.text :message
        t.string :notification_type   # info | success | warning | error | task_assigned | mention
        t.string :link                 # 클릭 시 이동할 URL
        t.string :related_type          # KanbanTask | MemberInquiry | ...
        t.integer :related_id
        t.boolean :is_read, default: false, null: false
        t.datetime :read_at
        t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
      end
      add_index :notifications, [:tenant_id, :user_id, :is_read], name: "idx_notifications_user_unread"
    end

    # task의 project_id 백필 (column에서 가져와서)
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE kanban_tasks
          SET project_id = (
            SELECT kanban_project_id FROM kanban_columns
            WHERE kanban_columns.id = kanban_tasks.kanban_column_id
          )
          WHERE project_id IS NULL
        SQL
      end
    end
  end
end
