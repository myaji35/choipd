class CreateBrandChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :brand_channels do |t|
      t.references :brand, null: false, foreign_key: true
      t.integer :tenant_id, default: 1, null: false
      t.string :platform, null: false
      t.string :account_handle
      t.string :profile_url
      t.string :connection_method, null: false
      t.string :credential_ref, limit: 64
      t.bigint :sns_account_id
      t.bigint :profile_account_id
      t.datetime :delegation_consent_at
      t.string :session_status, default: "unknown", null: false
      t.datetime :last_checked_at
      t.text :last_error
      t.string :posting_cadence
      t.text :notes

      t.timestamps
    end

    add_index :brand_channels, [ :brand_id, :platform, :account_handle ]
  end
end
