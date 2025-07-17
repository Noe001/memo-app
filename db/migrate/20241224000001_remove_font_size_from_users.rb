class RemoveFontSizeFromUsers < ActiveRecord::Migration[7.0]
  def change
    if column_exists?(:users, :font_size)
      remove_column :users, :font_size, :string
    end
  end
end
