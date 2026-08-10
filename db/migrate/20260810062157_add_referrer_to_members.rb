class AddReferrerToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :referrer_id, :integer
    add_index :members, :referrer_id
  end
end
