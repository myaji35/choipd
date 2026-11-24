class AddSearchQueriesToProfileAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :profile_accounts, :search_queries, :text
  end
end
