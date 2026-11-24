class AddBrandChannelPatrolAndBlogPublishing < ActiveRecord::Migration[8.1]
  def change
    add_column :brand_channels, :ego_server_name, :string, limit: 64
    add_reference :sns_scheduled_posts, :brand_channel, type: :bigint
    add_column :sns_scheduled_posts, :title, :string
  end
end
