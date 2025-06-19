class ApplicationController < ActionController::Base
  # CSRF保護を完全に無効化（開発環境）
  skip_before_action :verify_authenticity_token
  
  def current_user
    # セッションまたはクッキーからuser_idを取得（冗長化）
    user_id = session[:user_id] || cookies[:user_id]
    @current_user = user_id ? User.find_by(id: user_id) : nil
  end
  helper_method :current_user
  
  def authenticate_user!
    unless current_user
      redirect_to '/login', alert: 'ログインしてください'
    end
  end
end
