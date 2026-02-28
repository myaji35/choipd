class CreateKanbanTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :kanban_tasks do |t|
      t.references :kanban_column, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.string :priority
      t.date :due_date
      t.text :labels
      t.integer :position

      t.timestamps
    end
  end
end
