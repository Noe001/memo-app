class CreateGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :groups, if_not_exists: true do |t|
      t.string :name
      t.text :description
      t.integer :owner_id

      t.timestamps
    end
  end
end
