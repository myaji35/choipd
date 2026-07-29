class AddLayoutPresetToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :layout_preset, :string, default: "editorial", null: false
  end
end
