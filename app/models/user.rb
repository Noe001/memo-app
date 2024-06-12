class User < ApplicationRecord
  # パスワードをハッシュ化
  has_secure_password
  
end
