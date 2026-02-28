class CreateDistributorResources < ActiveRecord::Migration[8.1]
  def change
    create_table :distributor_resources do |t|
      t.string :title
      t.string :file_url
      t.string :file_type
      t.string :category
      t.string :required_plan
      t.integer :download_count, default: 0, null: false

      t.timestamps
    end
    add_index :distributor_resources, :category
    add_index :distributor_resources, :required_plan
  end
end
