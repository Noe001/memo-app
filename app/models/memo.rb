class Memo < ApplicationRecord
  # ユーザー情報と関連付ける
  belongs_to :user 
end
