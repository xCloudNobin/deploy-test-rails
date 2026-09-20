class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :title, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.integer :priority, null: false, default: 1
      t.string :owner, null: false, default: ""
      t.date :due_on

      t.timestamps
    end
    add_index :tasks, :status
    add_index :tasks, :priority
    add_index :tasks, :owner
  end
end
