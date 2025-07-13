class Memo < ApplicationRecord
  # ユーザー情報と関連付ける
  belongs_to :user 
  belongs_to :group, optional: true
  
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
  scope :by_group, ->(group) { where(group: group) }
  scope :personal, -> { where(group: nil) }
  scope :accessible_by, ->(user) {
    memos = arel_table
    groups = Group.arel_table
    user_groups = UserGroup.arel_table

    personal_memos = memos[:group_id].eq(nil).and(memos[:user_id].eq(user.id))
    owned_group_memos = groups[:owner_id].eq(user.id)
    member_group_memos = user_groups[:user_id].eq(user.id)

    left_joins(group: :user_groups)
      .where(personal_memos.or(owned_group_memos).or(member_group_memos))
      .distinct
  }
  scope :search, ->(query) {
    # Using LOWER() for case-insensitive search compatible with MySQL and PostgreSQL
    fuzzy_query = "%#{query.to_s.downcase}%" # Ensure query is a string and downcased
    where("LOWER(title) LIKE :query OR LOWER(description) LIKE :query", query: fuzzy_query)
  }
  
  # 並べ替え用スコープ
  scope :sort_by_updated_at, ->(direction = :desc) { order(updated_at: direction) }
  scope :sort_by_created_at, ->(direction = :desc) { order(created_at: direction) }
  scope :sort_by_title, ->(direction = :asc) { order(title: direction) }
  
  # 指定されたタグすべてを含むメモを取得するスコープ
  scope :with_tags, ->(tag_names) {
    tag_names_array = Array(tag_names).map(&:to_s).reject(&:blank?)
    return all if tag_names_array.empty?

    # サブクエリで対象メモ ID を取得し、外側で通常の ORDER BY を使う
    subquery = Memo.joins(:tags)
                   .where(tags: { name: tag_names_array })
                   .group('memos.id')
                   .having('COUNT(DISTINCT tags.id) = ?', tag_names_array.size)
                   .select(:id)

    where(id: subquery)
  }
  
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
  
  # グループ関連のメソッド
  def personal?
    group.nil?
  end
  
  def group_memo?
    group.present?
  end
  
  def accessible_by?(user)
    return true if self.user == user
    return false if personal?
    return true if group.owner == user
    group.member?(user)
  end

  def viewable_by?(user)
    return true if public_memo?
    return false unless user
    return true if user == self.user
    # In the future, this could be expanded to include group members for shared memos
    accessible_by?(user) if group_memo?
  end

  def toggle_visibility!
    if private_memo?
      public_memo!
    elsif public_memo?
      private_memo!
    end
    # 'shared' state is not part of this toggle logic
  end

  # Virtual attribute for tags
  def tags_string
    tags.map(&:name).join(', ')
  end

  def tags_string=(names)
    self.tags = names.split(',').map do |n|
      Tag.find_or_create_by_name(n.strip)
    end.compact
  end
  
  private
  
  def title_or_description_present
    if title.blank? && description.blank?
      errors.add(:base, "Title or description must be present")
    end
  end
end
