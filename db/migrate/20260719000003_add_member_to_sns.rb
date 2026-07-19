class AddMemberToSns < ActiveRecord::Migration[8.0]
  def change
    add_reference :sns_accounts, :member, foreign_key: true, null: true
    add_reference :sns_scheduled_posts, :member, foreign_key: true, null: true
  end
end
