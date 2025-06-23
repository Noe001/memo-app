class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :user_agent
      t.string :ip_address
      t.datetime :expires_at
      t.timestamps
    end
    
    add_index :sessions, :token, unique: true
    add_index :sessions, :expires_at
    add_index :sessions, [:user_id, :expires_at]
  end
end 
