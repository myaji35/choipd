class CreateKanbanProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :kanban_projects do |t|
      t.string :title
      t.text :description
      t.string :color

      t.timestamps
    end
  end
end
