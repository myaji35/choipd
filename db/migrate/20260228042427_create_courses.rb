class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.string :title
      t.text :description
      t.string :course_type
      t.integer :price
      t.string :thumbnail_url
      t.string :external_link
      t.boolean :published, default: false, null: false

      t.timestamps
    end
    add_index :courses, :course_type
    add_index :courses, :published
  end
end
