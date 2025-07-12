class SessionsController < ApplicationController
  before_action :logged_in, only: [:new, :create]
  
  # レート制限（後でRackミドルウェアで実装）
  # before_action :check_rate_limit, only: [:create]

  def new
    # 新しいAuthControllerにリダイレクト（Phase 4移行対応）
    redirect_to auth_login_path
  end

  def create
    # Supabaseトークンでのログイン
    supabase_token = params[:supabase_token]
    
    unless supabase_token
      flash.now[:alert] = 'ログインに失敗しました'
      render :new, status: :unprocessable_entity
      return
    end
    
    user_data = SupabaseAuth.verify_token(supabase_token)
    
    if user_data
      set_supabase_token(user_data[:token], user_data[:refresh_token])
      redirect_to root_path, notice: 'ログインしました'
    else
      flash.now[:alert] = '認証に失敗しました'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # Supabaseログアウト
    if current_user&.supabase_token
      SupabaseAuth.logout(current_user.supabase_token)
    end
    clear_supabase_token
    redirect_to auth_login_path, notice: 'ログアウトしました'
  end
  
  # 全セッションを削除（セキュリティ機能）
  def destroy_all
    # Supabaseの全セッションを削除
    if current_user&.supabase_token
      SupabaseAuth.logout(current_user.supabase_token)
    end
    clear_supabase_token
    redirect_to auth_login_path, notice: '全てのデバイスからログアウトしました'
  end

  private

  def logged_in
    if current_user
      redirect_to '/', notice: '既にログインしています'
    end
  end
  
  # レート制限チェック（今後実装）
  def check_rate_limit
    # Redis等を使用してレート制限を実装
    # 1分間に5回までのログイン試行を許可
  end
end
