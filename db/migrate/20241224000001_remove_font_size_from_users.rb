class RemoveFontSizeFromUsers < ActiveRecord::Migration[7.0]
  def change
    remove_column :users, :font_size, :string
  end
end 
