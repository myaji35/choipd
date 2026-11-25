class CreateScanOrganizerSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :scan_organizer_settings do |t|
      t.references :member, null: false, index: { unique: true }, foreign_key: true
      t.string :cloud_provider, default: "google_drive", null: false
      t.string :cloud_account_email
      t.text :cloud_refresh_token
      t.datetime :cloud_connected_at
      t.string :scan_folder_id
      t.string :scan_folder_name
      t.string :ai_provider
      t.text :ai_api_key
      t.string :ai_key_last4
      t.datetime :ai_key_verified_at
      t.timestamps
    end
  end
end
