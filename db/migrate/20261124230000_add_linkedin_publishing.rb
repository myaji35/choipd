class AddLinkedinPublishing < ActiveRecord::Migration[8.1]
  def change
    add_reference :sns_scheduled_posts, :profile_account, type: :integer, foreign_key: true

    %i[sns_scheduled_posts linkedin_newsletter_drafts].each do |table|
      change_table table do |t|
        t.datetime :approved_at
        t.datetime :published_at
        t.string :published_url
        t.string :result_message
      end
    end
  end
end
