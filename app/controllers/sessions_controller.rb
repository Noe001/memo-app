class SessionsController < ApplicationController
  before_action :set_user, only: [:create]
  before_action :logged_in, only: [:new, :create]
  
  # レート制限（後でRackミドルウェアで実装）
  # before_action :check_rate_limit, only: [:create]

  def new
  end

  def create
    if @user&.authenticate(params[:password])
      # セッションにuser_idを保存
      session[:user_id] = @user.id
      create_session_record # Call after @user is confirmed and session[:user_id] is set
      
      redirect_to root_path, notice: 'ログインしました' # root_path を使用
    else
      flash.now[:alert] = 'メールアドレスまたはパスワードが正しくありません'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # For web sessions, we don't have a specific DB session token.
    # destroy_session_record will delete the most recent one for the current_user.
    destroy_session_record if current_user # Call before session[:user_id] is deleted
    session.delete(:user_id)
    redirect_to login_path, notice: 'ログアウトしました' # login_path を使用
  end
  
  # 全セッションを削除（セキュリティ機能）
  def destroy_all
    if current_user
      current_user.sessions.destroy_all # DBのセッションレコードを削除
      session.delete(:user_id) # 現在のWebセッションもクリア
      redirect_to login_path, notice: '全てのデバイスからログアウトしました' # login_path を使用
    else
      redirect_to login_path # login_path を使用
    end
  end

  private

  def set_user
    @user = User.find_by(email: params[:email]&.downcase)
  end

  def logged_in
    if current_user
      redirect_to '/', notice: '既にログインしています'
    end
  end
  
  def create_session_record
    # セッション情報を記録（セキュリティのため）
    begin
      @user.sessions.create!(
        user_agent: request.user_agent || 'Unknown',
        ip_address: request.remote_ip || '0.0.0.0'
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create session record: #{e.message}"
      # セッション記録に失敗してもログイン処理は継続
    end
  end
  
  def destroy_session_record
    # 現在のセッション記録を削除（最新のセッションを削除）
    current_user.sessions.order(created_at: :desc).first&.destroy
  end
  
  # レート制限チェック（今後実装）
  def check_rate_limit
    # Redis等を使用してレート制限を実装
    # 1分間に5回までのログイン試行を許可
  end
end
