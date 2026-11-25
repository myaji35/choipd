class CreateScanItems < ActiveRecord::Migration[8.0]
  def change
    create_table :scan_items do |t|
      t.references :member, null: false, foreign_key: true
      t.string :source_file_id, null: false
      t.string :source_name
      t.string :mime_type
      t.string :status, default: "pending", null: false
      t.string :category
      t.decimal :confidence, precision: 4, scale: 3
      t.text :extracted_json
      t.string :result_location
      t.string :failure_reason
      t.datetime :processed_at
      t.timestamps
      t.index [ :member_id, :source_file_id ], unique: true
    end
  end
end
