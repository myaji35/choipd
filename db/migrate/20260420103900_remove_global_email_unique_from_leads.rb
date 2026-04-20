class RemoveGlobalEmailUniqueFromLeads < ActiveRecord::Migration[8.1]
  def change
    remove_index :leads, :email if index_exists?(:leads, :email, name: "index_leads_on_email")
  end
end
