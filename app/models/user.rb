class User < ApplicationRecord
  # BCryptパスワードを設定して認証するためのメソッド
  has_secure_password
  
  # セキュリティ強化：強力なバリデーション
  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :email, presence: true, 
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, 
                       length: { minimum: 8 }, 
                       on: :create
  validates :password_confirmation, presence: true, on: :create
  
  # テーマ設定のバリデーション
  validates :theme, inclusion: { in: %w[light dark high-contrast], 
                                message: "は有効なテーマを選択してください" }
  

  
  # ユーザーが作成したメモと関連付ける
  has_many :memos, dependent: :destroy
  
  # グループ関連の関連付け
  has_many :owned_groups, class_name: 'Group', foreign_key: 'owner_id', dependent: :destroy
  has_many :user_groups, dependent: :destroy
  has_many :groups, through: :user_groups
  has_many :sent_invitations, class_name: 'Invitation', foreign_key: 'invited_by_id', dependent: :destroy
  has_many :received_invitations, class_name: 'Invitation', foreign_key: 'invited_user_id', dependent: :destroy
  
  # セキュリティ：メールアドレスを小文字で保存
  before_save :downcase_email
  
  # セキュリティ強化：セッション管理
  has_many :sessions, dependent: :destroy
  
  # グループ関連のメソッド
  def all_groups
    # This method returns a relation of all groups a user is associated with (owned or member).
    # It avoids N+1 queries compared to the previous implementation.
    Group.left_joins(:user_groups)
         .where(owner_id: self.id)
         .or(Group.where(user_groups: { user_id: self.id }))
         .distinct
  end
  
  def group_role(group)
    return 'owner' if group.owner == self
    user_groups.find_by(group: group)&.role
  end
  
  def can_access_group?(group)
    group.owner == self || groups.include?(group)
  end
  
  private
  
  def downcase_email
    self.email = email.downcase
  end
end
