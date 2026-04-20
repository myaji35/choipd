class AddDistributorExtraColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :distributors, :approved_at, :datetime unless column_exists?(:distributors, :approved_at)
    add_column :distributors, :slug, :string unless column_exists?(:distributors, :slug)
    add_index  :distributors, :slug, unique: true unless index_exists?(:distributors, :slug)
  end
end
