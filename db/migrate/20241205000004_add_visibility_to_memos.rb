class AddVisibilityToMemos < ActiveRecord::Migration[7.1]
  def change
    add_column :memos, :visibility, :integer, default: 0
    add_index :memos, :visibility
    add_index :memos, [:user_id, :visibility]
    add_index :memos, [:user_id, :updated_at]
  end
end 
