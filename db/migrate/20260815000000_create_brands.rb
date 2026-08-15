class CreateBrands < ActiveRecord::Migration[8.1]
  def change
    create_table :brands do |t|
      t.integer :member_id
      t.string :slug, null: false
      t.string :name, null: false
      t.string :website_url
      t.text :description
      t.string :logo_url
      t.string :business_type
      t.string :region
      t.boolean :published, default: false, null: false
      t.integer :tenant_id, default: 1, null: false

      t.timestamps
    end

    add_index :brands, :slug, unique: true
    add_index :brands, :published
    add_index :brands, :tenant_id
    add_index :brands, :member_id
  end
end
