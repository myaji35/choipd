class AddWithdrawnAtToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :withdrawn_at, :datetime
    add_index :members, :withdrawn_at
  end
end
