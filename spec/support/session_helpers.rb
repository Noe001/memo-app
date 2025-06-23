module SessionHelpers
  def login_user(user = nil)
    user ||= create(:user)
    session[:user_id] = user.id
    user
  end
  
  def logout_user
    session.delete(:user_id)
    @current_user = nil
  end
  
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
  
  # システムテスト用のログイン
  def login_as(user)
    visit new_sessions_path
    fill_in 'email', with: user.email
    fill_in 'password', with: user.password
    click_button 'ログイン'
  end
  
  # システムテスト用のサインアップ
  def signup_as(user_attributes)
    visit signup_path
    fill_in 'Name', with: user_attributes[:name]
    fill_in 'Email', with: user_attributes[:email]
    fill_in 'Password', with: user_attributes[:password]
    fill_in 'Password confirmation', with: user_attributes[:password_confirmation]
    click_button 'アカウント作成'
  end
end 
