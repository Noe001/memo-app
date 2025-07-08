class UserGroup < ApplicationRecord
  belongs_to :user
  belongs_to :group
  
  enum role: {
    member: 0,
    admin: 1,
    owner: 2
  }
  
  validates :user_id, uniqueness: { scope: :group_id }
  validates :role, presence: true
  
  scope :by_role, ->(role) { where(role: role) }
  scope :admins_and_owners, -> { where(role: [:admin, :owner]) }
  
  def display_role
    case role
    when 'owner'
      'オーナー'
    when 'admin'
      '管理者'
    when 'member'
      'メンバー'
    else
      role.humanize
    end
  end
end 
