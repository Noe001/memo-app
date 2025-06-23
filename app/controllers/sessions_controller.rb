class SessionsController < ApplicationController
  before_action :set_user, only: [:create]
  before_action :logged_in, only: [:new, :create]
  
  # レート制限（後でRackミドルウェアで実装）
  # before_action :check_rate_limit, only: [:create]

  def new
  end

  def create
    if @user&.authenticate(params[:password])
      # セッションとクッキーの両方に保存（冗長化）
      session[:user_id] = @user.id
      cookies.permanent[:user_id] = @user.id
      
      redirect_to '/', notice: 'ログインしました'
    else
      flash.now[:alert] = 'メールアドレスまたはパスワードが正しくありません'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    cookies.delete(:user_id)
    redirect_to '/login', notice: 'ログアウトしました'
  end
  
  # 全セッションを削除（セキュリティ機能）
  def destroy_all
    if current_user
      current_user.sessions.destroy_all
      session[:user_id] = nil
      redirect_to '/login', notice: '全てのデバイスからログアウトしました'
    else
      redirect_to '/login'
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
