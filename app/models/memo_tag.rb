class MemoTag < ApplicationRecord
  belongs_to :memo
  belongs_to :tag
  
  validates :memo_id, uniqueness: { scope: :tag_id }
end 
