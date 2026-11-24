class CreateNaverPeopleSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :naver_people_submissions do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :profile_account, null: false, foreign_key: true
      t.string :target_digest
      t.text :items
      t.string :status, default: "preparing", null: false
      t.string :ego_space_id
      t.text :filled_items
      t.text :manual_items
      t.string :result_message
      t.datetime :prepared_at
      t.datetime :submitted_at
      t.datetime :cancelled_at
      t.timestamps
    end
  end
end
