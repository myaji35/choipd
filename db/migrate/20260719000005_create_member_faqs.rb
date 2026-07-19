class CreateMemberFaqs < ActiveRecord::Migration[8.0]
  def change
    create_table :member_faqs do |t|
      t.references :member, foreign_key: true, null: false
      t.string :question, null: false
      t.text :answer, null: false
      t.integer :sort_order, default: 0
      t.integer :is_published, default: 1

      t.timestamps
    end
  end
end
