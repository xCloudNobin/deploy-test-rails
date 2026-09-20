class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.string :name, null: false
      t.text :payload, default: ""
      t.integer :status, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.string :last_error
      t.datetime :processed_at

      t.timestamps
    end
    add_index :jobs, :status
  end
end
