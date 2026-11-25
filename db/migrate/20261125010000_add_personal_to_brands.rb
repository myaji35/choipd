class AddPersonalToBrands < ActiveRecord::Migration[8.1]
  def change
    add_column :brands, :personal, :boolean, default: false, null: false
    add_index :brands, [ :member_id, :personal ], unique: true, where: "personal = TRUE"
  end
end
