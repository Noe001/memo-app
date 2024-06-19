class User < ApplicationRecord
  # BCryptパスワードを設定して認証するためのメソッド
  has_secure_password
end
