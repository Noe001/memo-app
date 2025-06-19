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
  
  # ユーザーが作成したメモと関連付ける
  has_many :memos, dependent: :destroy
  
  # セキュリティ：メールアドレスを小文字で保存
  before_save :downcase_email
  
  # セキュリティ：アカウントロック機能
  attr_accessor :failed_login_attempts
  
  # セキュリティ強化：セッション管理
  has_many :sessions, dependent: :destroy
  
  private
  
  def downcase_email
    self.email = email.downcase
  end
end
