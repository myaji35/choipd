class CreateSubscriptionPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_plans do |t|
      t.string :name
      t.integer :price
      t.text :features
      t.integer :max_distributors

      t.timestamps
    end
  end
end
