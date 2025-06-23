class Session < ApplicationRecord
  belongs_to :user
  
  validates :token, presence: true, uniqueness: true
  validates :user_agent, length: { maximum: 500 }
  validates :ip_address, length: { maximum: 45 }
  
  before_create :generate_token
  
  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  
  def expired?
    expires_at <= Time.current
  end
  
  def self.cleanup_expired
    expired.delete_all
  end
  
  private
  
  def generate_token
    return if token.present?
    
    # 最大10回試行してユニークなトークンを生成
    10.times do
      candidate_token = SecureRandom.hex(32)
      unless Session.exists?(token: candidate_token)
        self.token = candidate_token
        break
      end
    end
    
    # 10回試行しても重複する場合は、タイムスタンプを含めて確実にユニークにする
    self.token ||= "#{SecureRandom.hex(28)}_#{Time.current.to_i}"
    self.expires_at ||= 30.days.from_now
  end
end 
