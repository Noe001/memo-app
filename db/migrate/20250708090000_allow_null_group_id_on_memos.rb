class AllowNullGroupIdOnMemos < ActiveRecord::Migration[7.1]
  def change
    change_column_null :memos, :group_id, true
  end
end 
