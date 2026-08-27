class CreateLlmConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_configs do |t|
      t.string :purpose, null: false
      t.string :provider, null: false, default: "anthropic"
      t.string :model, null: false
      t.integer :max_tokens
      t.float :temperature
      t.boolean :enabled, null: false, default: true
      t.string :updated_by
      t.integer :tenant_id, default: 1, null: false

      t.timestamps
    end

    add_index :llm_configs, :purpose, unique: true
    add_index :llm_configs, :tenant_id
  end
end
