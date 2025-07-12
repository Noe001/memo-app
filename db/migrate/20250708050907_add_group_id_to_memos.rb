class AddGroupIdToMemos < ActiveRecord::Migration[7.1]
  def change
    add_reference :memos, :group, null: false, foreign_key: true
  end
end
