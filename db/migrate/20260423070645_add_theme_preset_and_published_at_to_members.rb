class AddThemePresetAndPublishedAtToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :theme_preset, :string
    add_column :members, :published_at, :datetime
  end
end
