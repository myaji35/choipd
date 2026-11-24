class CreateNaverPeopleTargets < ActiveRecord::Migration[8.0]
  def change
    create_table :naver_people_targets do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :profile_account, null: false, foreign_key: true, index: { unique: true }
      t.text :data
      t.string :status, default: "draft", null: false
      t.datetime :approved_at
      t.string :approved_draft_digest
      t.timestamps
    end
  end
end
