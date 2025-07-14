class CreateGroupsTable < ActiveRecord::Migration[7.1]
  def change
    create_table :groups do |t|
      t.string :name
      t.text :description
      t.integer :owner_id

      t.timestamps
    end
  end
end
