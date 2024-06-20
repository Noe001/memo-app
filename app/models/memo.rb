class Memo < ApplicationRecord
  # ユーザー情報と関連付ける
  belongs_to :user
  # タイトル、概要の入力は必須にする
  validates :title, presence: true
  validates :description, presence: true 
end
