class Group < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  has_many :user_groups, dependent: :destroy
  has_many :users, through: :user_groups
  has_many :memos, dependent: :destroy
  has_many :invitations, dependent: :destroy
  
  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }
  
  scope :owned_by, ->(user) { where(owner: user) }
  scope :with_user, ->(user) { joins(:user_groups).where(user_groups: { user: user }) }
  
  def members
    users.includes(:user_groups).where(user_groups: { group: self })
  end
  
  def member?(user)
    user_groups.exists?(user: user)
  end
  
  def role_for(user)
    return 'owner' if owner == user
    user_groups.find_by(user: user)&.role
  end
  
  def admin_or_owner?(user)
    role = role_for(user)
    %w[owner admin].include?(role)
  end
  
  def can_edit?(user)
    member?(user)
  end
  
  def can_manage?(user)
    admin_or_owner?(user)
  end
end 
