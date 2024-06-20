class User < ApplicationRecord
  # BCryptパスワードを設定して認証するためのメソッド
  has_secure_password
  # ユーザーが作成したメモと関連付ける
  has_many :memos
end
