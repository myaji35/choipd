class AddIdentityToDistributors < ActiveRecord::Migration[8.1]
  def change
    add_column :distributors, :identity_md, :text unless column_exists?(:distributors, :identity_md)
    add_column :distributors, :identity_filename, :string unless column_exists?(:distributors, :identity_filename)
    add_column :distributors, :identity_updated_at, :datetime unless column_exists?(:distributors, :identity_updated_at)
    add_column :distributors, :identity_json, :text unless column_exists?(:distributors, :identity_json)
    add_column :distributors, :identity_parsed_at, :datetime unless column_exists?(:distributors, :identity_parsed_at)
  end
end
