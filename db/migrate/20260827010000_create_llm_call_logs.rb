class CreateLlmCallLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_call_logs do |t|
      t.string :purpose
      t.string :model
      t.string :provider
      t.integer :tokens_in
      t.integer :tokens_out
      t.integer :duration_ms
      t.string :status, null: false
      t.text :error
      t.integer :tenant_id, default: 1, null: false

      t.timestamps
    end

    add_index :llm_call_logs, :purpose
    add_index :llm_call_logs, :status
    add_index :llm_call_logs, :created_at
    add_index :llm_call_logs, :tenant_id
  end
end
