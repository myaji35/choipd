class CreateLinkedinInvitationActions < ActiveRecord::Migration[8.0]
  def change
    create_table :linkedin_invitation_actions do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :profile_account, null: false, foreign_key: true, index: false
      t.string :invitation_key, null: false
      t.string :kind
      t.string :name, null: false
      t.string :headline
      t.string :action, null: false
      t.string :status, default: "approved", null: false
      t.datetime :approved_at
      t.datetime :executed_at
      t.text :result_message
      t.timestamps

      t.index [ :profile_account_id, :invitation_key, :action ]
    end
  end
end
