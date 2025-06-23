class AddUserPreferencesToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :font_size, :string, default: 'medium'
    add_column :users, :keyboard_shortcuts_enabled, :boolean, default: true
  end
end 
