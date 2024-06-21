class AddUserIdToMemos < ActiveRecord::Migration[7.1]
  def change
    add_column :memos, :user_id, :integer
  end
end
