class CreateKanbanColumns < ActiveRecord::Migration[8.1]
  def change
    create_table :kanban_columns do |t|
      t.references :kanban_project, null: false, foreign_key: true
      t.string :title
      t.integer :position

      t.timestamps
    end
  end
end
