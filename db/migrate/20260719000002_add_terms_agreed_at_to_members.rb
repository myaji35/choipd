class AddTermsAgreedAtToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :terms_agreed_at, :datetime
    add_index :members, :terms_agreed_at
  end
end
