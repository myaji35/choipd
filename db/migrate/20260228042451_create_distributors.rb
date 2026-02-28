class CreateDistributors < ActiveRecord::Migration[8.1]
  def change
    create_table :distributors do |t|
      t.string :name
      t.string :email
      t.string :business_type
      t.string :region
      t.string :status
      t.string :subscription_plan
      t.decimal :total_revenue, precision: 15, scale: 2, default: 0

      t.timestamps
    end
    add_index :distributors, :email, unique: true
    add_index :distributors, :status
    add_index :distributors, :subscription_plan
  end
end
