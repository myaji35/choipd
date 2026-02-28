class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :distributor, null: false, foreign_key: true
      t.decimal :amount
      t.string :status
      t.string :payment_method
      t.datetime :paid_at

      t.timestamps
    end
  end
end
