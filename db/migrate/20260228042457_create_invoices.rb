class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :distributor, null: false, foreign_key: true
      t.references :payment, null: false, foreign_key: true
      t.decimal :amount
      t.string :status
      t.datetime :issued_at

      t.timestamps
    end
  end
end
