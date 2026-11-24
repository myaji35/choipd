class CreateLinkedinNewsletterDrafts < ActiveRecord::Migration[8.0]
  def change
    create_table :linkedin_newsletter_drafts do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :profile_account, null: false, foreign_key: true, index: false
      t.string :newsletter_name
      t.string :title, null: false
      t.text :body
      t.string :status, default: "draft", null: false
      t.datetime :archived_at
      t.timestamps

      t.index [ :profile_account_id, :status ]
    end
  end
end
