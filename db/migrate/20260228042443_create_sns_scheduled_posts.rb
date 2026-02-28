class CreateSnsScheduledPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :sns_scheduled_posts do |t|
      t.string :content_type
      t.integer :content_id
      t.string :platform
      t.text :message
      t.datetime :scheduled_at
      t.string :status

      t.timestamps
    end
  end
end
