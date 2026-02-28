class CreateSnsPostHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :sns_post_histories do |t|
      t.references :sns_scheduled_post, null: false, foreign_key: true
      t.string :action
      t.string :status
      t.text :response

      t.timestamps
    end
  end
end
