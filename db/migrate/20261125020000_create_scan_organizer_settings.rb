class CreateScanOrganizerSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :scan_organizer_settings do |t|
      t.references :member, null: false, index: { unique: true }, foreign_key: true
      t.string :cloud_provider, default: "google_drive", null: false
      t.string :ai_provider
      t.text :ai_api_key
      t.string :ai_key_last4
      t.datetime :ai_key_verified_at
      t.string :receipts_sheet_name
      t.string :documents_folder_name
      t.string :review_folder_name
      t.string :run_frequency, default: "daily"
      t.timestamps
    end
  end
end
