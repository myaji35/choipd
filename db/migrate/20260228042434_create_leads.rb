class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads do |t|
      t.string :email
      t.datetime :subscribed_at

      t.timestamps
    end
    add_index :leads, :email, unique: true
  end
end
