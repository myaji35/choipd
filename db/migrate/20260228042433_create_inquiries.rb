class CreateInquiries < ActiveRecord::Migration[8.1]
  def change
    create_table :inquiries do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.text :message
      t.string :inquiry_type
      t.string :status, default: 'pending'

      t.timestamps
    end
    add_index :inquiries, :inquiry_type
    add_index :inquiries, :status
  end
end
