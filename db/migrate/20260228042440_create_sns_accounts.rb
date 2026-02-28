class CreateSnsAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :sns_accounts do |t|
      t.string :platform
      t.string :account_name
      t.text :access_token_encrypted
      t.boolean :is_active

      t.timestamps
    end
  end
end
