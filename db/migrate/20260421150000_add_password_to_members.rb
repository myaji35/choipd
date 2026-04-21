class AddPasswordToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :password_digest, :string
    add_column :members, :last_sign_in_at, :datetime
  end
end
