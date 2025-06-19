class CreateMemoTags < ActiveRecord::Migration[7.1]
  def change
    create_table :memo_tags do |t|
      t.references :memo, null: false, foreign_key: true, index: false
      t.references :tag, null: false, foreign_key: true, index: false
      t.timestamps
    end
    
    add_index :memo_tags, [:memo_id, :tag_id], unique: true
    add_index :memo_tags, :tag_id
  end
end 
