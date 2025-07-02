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
    # Using LOWER() for case-insensitive search compatible with MySQL and PostgreSQL
    fuzzy_query = "%#{query.to_s.downcase}%" # Ensure query is a string and downcased
    where("LOWER(title) LIKE :query OR LOWER(description) LIKE :query", query: fuzzy_query)
  }
  
  # 並べ替え用スコープ
  scope :sort_by_updated_at, ->(direction = :desc) { order(updated_at: direction) }
  scope :sort_by_created_at, ->(direction = :desc) { order(created_at: direction) }
  scope :sort_by_title, ->(direction = :asc) { order(title: direction) }
  
  # 並べ替えオプションを取得するクラスメソッド
  def self.sort_options
    {
      'updated_at' => '更新日時',
      'created_at' => '作成日時', 
      'title' => 'タイトル'
    }
  end
  
  # 並べ替えを適用するメソッド
  def self.apply_sort(sort_by = 'updated_at', direction = 'desc')
    direction = direction.to_s.downcase == 'asc' ? :asc : :desc
    
    case sort_by.to_s
    when 'updated_at'
      sort_by_updated_at(direction)
    when 'created_at'
      sort_by_created_at(direction)
    when 'title'
      sort_by_title(direction)
    else
      recent # デフォルトは更新日時（新しい順）
    end
  end
  
  # 公開/非公開機能
  enum visibility: { private_memo: 0, public_memo: 1, shared: 2 }
  
  private
  
  def title_or_description_present
    if title.blank? && description.blank?
      errors.add(:base, "Title or description must be present")
    end
  end
end
