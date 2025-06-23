class Tag < ApplicationRecord
  has_many :memo_tags, dependent: :destroy
  has_many :memos, through: :memo_tags
  
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :color, format: { with: /\A#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\z/ }
  
  before_save :downcase_name
  
  scope :popular, -> { joins(:memos).group('tags.id').order('COUNT(memos.id) DESC') }
  
  def self.find_or_create_by_name(name)
    find_or_create_by(name: name.downcase)
  end
  
  private
  
  def downcase_name
    self.name = name.downcase
  end
end 
