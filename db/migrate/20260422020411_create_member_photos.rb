class CreateMemberPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :member_photos do |t|
      t.references :member, null: false, foreign_key: true, index: true
      t.string :caption
      t.string :category, default: "daily" # daily / workshop / product / press
      t.integer :sort_order, default: 0
      t.datetime :taken_at
      t.datetime :uploaded_at
      t.integer :file_size
      t.integer :width
      t.integer :height
      t.timestamps
    end
    add_index :member_photos, [:member_id, :uploaded_at]
    add_index :member_photos, [:member_id, :category]
  end
end
