class CreateDistributorActivityLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :distributor_activity_logs do |t|
      t.references :distributor, null: false, foreign_key: true
      t.string :activity_type
      t.text :description
      t.text :metadata

      t.timestamps
    end
  end
end
