class CreateTags < ActiveRecord::Migration[7.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :color, default: '#007bff'
      t.text :description
      t.timestamps
    end
    
    add_index :tags, :name, unique: true
  end
end 
