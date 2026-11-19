class CreateProfileAccountsAndSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :profile_accounts do |t|
      t.integer :tenant_id, default: 1, null: false
      t.integer :member_id
      t.string :platform, null: false
      t.string :login_id
      t.string :external_id
      t.string :display_name
      t.string :headline
      t.string :profile_url
      t.string :auth_status
      t.string :session_status, default: "unknown", null: false
      t.datetime :last_checked_at
      t.text :last_error
      t.boolean :is_active, default: true, null: false
      t.text :notes
      t.timestamps
    end
    add_index :profile_accounts, :tenant_id
    add_index :profile_accounts, :member_id
    add_index :profile_accounts, [ :tenant_id, :platform, :external_id ], unique: true

    create_table :profile_snapshots do |t|
      t.references :profile_account, null: false, foreign_key: true, index: false
      t.integer :tenant_id, default: 1, null: false
      t.datetime :captured_at, null: false
      t.string :source, default: "ego", null: false
      t.text :data
      t.timestamps
    end
    add_index :profile_snapshots, [ :profile_account_id, :captured_at ]
  end
end
