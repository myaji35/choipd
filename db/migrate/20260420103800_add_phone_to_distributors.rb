class AddPhoneToDistributors < ActiveRecord::Migration[8.1]
  def change
    add_column :distributors, :phone, :string unless column_exists?(:distributors, :phone)
  end
end
