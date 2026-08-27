class CreateSnsFollowerSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :sns_follower_snapshots do |t|
      t.references :sns_account, null: false, foreign_key: true
      t.integer :follower_count, null: false
      t.string :source, null: false, default: "manual"
      t.datetime :captured_at, null: false
      t.integer :tenant_id, default: 1, null: false

      t.timestamps
    end

    add_index :sns_follower_snapshots, [ :sns_account_id, :captured_at ]
    add_index :sns_follower_snapshots, :tenant_id
  end
end
