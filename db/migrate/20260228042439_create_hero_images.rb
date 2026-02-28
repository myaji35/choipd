class CreateHeroImages < ActiveRecord::Migration[8.1]
  def change
    create_table :hero_images do |t|
      t.string :filename
      t.string :alt_text
      t.boolean :is_active
      t.integer :display_order

      t.timestamps
    end
  end
end
