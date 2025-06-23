class Memo < ApplicationRecord
  # ユーザー情報と関連付ける
  belongs_to :user 
  
  # バリデーション強化
  validates :title, length: { maximum: 255 }
  validates :description, length: { maximum: 10000 }
  validate :title_or_description_present
  
  # タグ機能
  has_many :memo_tags, dependent: :destroy
  has_many :tags, through: :memo_tags
  
  # スコープ（検索・フィルタリング用）
  scope :recent, -> { order(updated_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :search, ->(query) {
    where("title ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%")
  }
  
  # 公開/非公開機能
  enum visibility: { private_memo: 0, public_memo: 1, shared: 2 }
  
  private
  
  def title_or_description_present
    if title.blank? && description.blank?
      errors.add(:base, "Title or description must be present")
    end
  end
end
