class AddMemberIdToAdminUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :admin_users, :member_id, :integer
    add_index :admin_users, :member_id
  end
end
