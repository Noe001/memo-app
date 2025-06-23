class ApplicationController < ActionController::Base
  # CSRF保護はデフォルトで有効になっています。
  # APIエンドポイントや特定のケースで無効化する場合は、対象のコントローラーで個別に設定してください。
  # 例: protect_from_forgery with: :null_session, if: -> { request.format.json? }
  
  def current_user
    # セッションからuser_idを取得
    # @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
    # より安全なセッション管理のため、Sessionモデル経由での検索を検討 (今後の改善点)
    # 現状は session[:user_id] のみを使用します
    if session[:user_id]
      @current_user ||= User.find_by(id: session[:user_id])
    else
      @current_user = nil
    end
  end
  helper_method :current_user
  
  def authenticate_user!
    unless current_user
      redirect_to login_path, alert: 'ログインしてください' # Changed to use login_path
    end
  end
end
