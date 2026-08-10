class AddCareerNoteToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :career_note, :text
  end
end
