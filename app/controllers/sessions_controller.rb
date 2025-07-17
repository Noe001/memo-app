class SessionsController < ApplicationController
  before_action :logged_in, only: [:new, :create]
  
  # レート制限（後でRackミドルウェアで実装）
  # before_action :check_rate_limit, only: [:create]

  def new
    # 新しいAuthControllerにリダイレクト（Phase 4移行対応）
    redirect_to auth_login_path
  end

  def create
    Rails.logger.info "SessionsController#create started with params: #{params.except(:supabase_token).inspect}"
    
    begin
      # Supabaseトークンでのログイン
      supabase_token = params[:supabase_token]
      Rails.logger.debug "Received supabase_token: #{supabase_token.present? ? 'present (first 8 chars: ' + supabase_token[0..7] + '...)' : 'missing'}"
      
      unless supabase_token
        Rails.logger.warn "Missing supabase_token parameter. Full params: #{params.inspect}"
        flash.now[:alert] = 'ログインに失敗しました'
        render :new, status: :unprocessable_entity
        return
      end
      
      Rails.logger.info "Verifying supabase token (first 8 chars: #{supabase_token[0..7]}...)"
      Rails.logger.debug "Token verification request to SupabaseAuth started at #{Time.current}"
      user_data = SupabaseAuth.verify_token(supabase_token)
      Rails.logger.debug "Token verification response: #{user_data.present? ? 'success' : 'failure'}"
      
      if user_data
        Rails.logger.info "Token verification successful. User data keys: #{user_data.keys}"
        Rails.logger.debug "Setting supabase tokens (token present: #{user_data[:token].present?}, refresh_token present: #{user_data[:refresh_token].present?})"
        set_supabase_token(user_data[:token], user_data[:refresh_token])
        redirect_to root_path, notice: 'ログインしました'
      else
        Rails.logger.warn "Token verification failed"
        flash.now[:alert] = '認証に失敗しました'
        render :new, status: :unprocessable_entity
      end
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT Decode Error in SessionsController#create: #{e.message}"
      Rails.logger.error "Backtrace:\n#{e.backtrace.first(5).join("\n")}"
    rescue SupabaseAuth::Error => e
      Rails.logger.error "Supabase Auth Error in SessionsController#create: #{e.message}"
      Rails.logger.error "Backtrace:\n#{e.backtrace.first(5).join("\n")}"
    rescue => e
      Rails.logger.error "Unexpected Error in SessionsController#create: #{e.class} - #{e.message}"
      Rails.logger.error "Backtrace:\n#{e.backtrace.first(5).join("\n")}"
      flash.now[:alert] = 'システムエラーが発生しました'
      render :new, status: :internal_server_error
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
