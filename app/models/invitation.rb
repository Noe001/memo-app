class Invitation < ApplicationRecord
  belongs_to :group
  belongs_to :invited_by, class_name: 'User'
  belongs_to :invited_user, class_name: 'User', optional: true
  
  enum role: {
    member: 0,
    admin: 1
  }
  
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :role, presence: true
  
  scope :pending, -> { where(accepted_at: nil) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :valid_tokens, -> { where('expires_at > ?', Time.current) }
  
  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create
  
  def accepted?
    accepted_at.present?
  end
  
  def expired?
    expires_at < Time.current
  end
  
  def valid_token?
    !expired? && !accepted?
  end
  
  def accept!(user)
    return false if expired? || accepted?
    
    transaction do
      update!(accepted_at: Time.current, invited_user: user)
      group.user_groups.create!(user: user, role: role)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
  
  def display_role
    case role
    when 'admin'
      '管理者'
    when 'member'
      'メンバー'
    else
      role.humanize
    end
  end
  
  private
  
  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end
  
  def set_expiry
    self.expires_at = 7.days.from_now
  end
end 
