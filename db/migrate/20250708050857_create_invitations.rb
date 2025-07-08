class CreateInvitations < ActiveRecord::Migration[7.1]
  def change
    create_table :invitations do |t|
      t.references :group, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: true
      t.references :invited_user, null: false, foreign_key: true
      t.string :email
      t.string :token
      t.integer :role
      t.datetime :expires_at
      t.datetime :accepted_at

      t.timestamps
    end
  end
end
