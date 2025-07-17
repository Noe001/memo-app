class AuthController < ApplicationController
  protect_from_forgery with: :exception, unless: -> { request.format.json? }
  
  def new
    # ログインページを表示
    if current_user
      redirect_to root_path, notice: '既にログインしています'
      return
    end
    
    render :new
  end
  
  def login
    email = params[:email]
    password = params[:password]
    
    if email.blank? || password.blank?
      render json: { error: 'メールアドレスとパスワードを入力してください' }, status: :bad_request
      return
    end
    
    begin
      # Supabase認証
      auth_result = SupabaseAuth.sign_in(email, password)
      
      if auth_result[:success]
        # トークンをCookieに保存
        set_supabase_token(auth_result[:access_token])
        
        respond_to do |format|
          format.html { redirect_to root_path, notice: 'ログインしました' }
          format.json { 
            render json: { 
              success: true, 
              message: 'ログインしました',
              user: auth_result[:user],
              access_token: auth_result[:access_token]
            }
          }
        end
      else
        error_message = auth_result[:error] || 'ログインに失敗しました'
        respond_to do |format|
          format.html { 
            flash.now[:alert] = error_message
            render :new 
          }
          format.json { render json: { error: error_message }, status: :unauthorized }
        end
      end
    rescue => e
      Rails.logger.error "Login error: #{e.message}"
      error_message = 'ログイン中にエラーが発生しました'
      
      respond_to do |format|
        format.html { 
          flash.now[:alert] = error_message
          render :new 
        }
        format.json { render json: { error: error_message }, status: :internal_server_error }
      end
    end
  end
  
  def signup
    email = params[:email]
    password = params[:password]
    name = params[:name]
    
    if email.blank? || password.blank? || name.blank?
      render json: { error: '必要な情報を入力してください' }, status: :bad_request
      return
    end
    
    begin
      # Supabase認証でユーザー作成
      auth_result = SupabaseAuth.sign_up(email, password, name)
      
      if auth_result[:success]
        # トークンをCookieに保存
        set_supabase_token(auth_result[:access_token])
        
        respond_to do |format|
          format.html { redirect_to root_path, notice: 'アカウントを作成しました' }
          format.json { 
            render json: { 
              success: true, 
              message: 'アカウントを作成しました',
              user: auth_result[:user],
              access_token: auth_result[:access_token]
            }
          }
        end
      else
        error_message = auth_result[:error] || 'アカウント作成に失敗しました'
        respond_to do |format|
          format.html { 
            flash.now[:alert] = error_message
            render :new 
          }
          format.json { render json: { error: error_message }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error "Signup error: #{e.message}"
      error_message = 'アカウント作成中にエラーが発生しました'
      
      respond_to do |format|
        format.html { 
          flash.now[:alert] = error_message
          render :new 
        }
        format.json { render json: { error: error_message }, status: :internal_server_error }
      end
    end
  end
  
  def logout
    clear_supabase_token
    
    # Supabaseセッションの終了
    begin
      SupabaseAuth.sign_out(current_user&.supabase_token) if current_user&.supabase_token
    rescue => e
      Rails.logger.error "Logout error: #{e.message}"
    end
    
    respond_to do |format|
      format.html { redirect_to auth_login_path, notice: 'ログアウトしました' }
      format.json { render json: { success: true, message: 'ログアウトしました' } }
    end
  end
  
  def refresh_token
    current_token = extract_supabase_token
    
    if current_token.blank?
      render json: { error: 'トークンが見つかりません' }, status: :unauthorized
      return
    end
    
    begin
      # トークンを更新
      refresh_result = SupabaseAuth.refresh_token(current_token)
      
      if refresh_result[:success]
        # 新しいトークンをCookieに保存
        set_supabase_token(refresh_result[:access_token])
        
        render json: { 
          success: true, 
          access_token: refresh_result[:access_token],
          user: refresh_result[:user]
        }
      else
        clear_supabase_token
        render json: { error: 'トークンの更新に失敗しました' }, status: :unauthorized
      end
    rescue => e
      Rails.logger.error "Token refresh error: #{e.message}"
      clear_supabase_token
      render json: { error: 'トークンの更新中にエラーが発生しました' }, status: :internal_server_error
    end
  end
  
  def current_user_info
    if current_user
      render json: {
        success: true,
        user: {
          id: current_user.id,
          email: current_user.email,
          name: current_user.name,
          theme: current_user.theme,
          keyboard_shortcuts_enabled: current_user.keyboard_shortcuts_enabled
        }
      }
    else
      render json: { error: 'ログインが必要です' }, status: :unauthorized
    end
  end
  
  private
  
  def auth_params
    params.permit(:email, :password, :name)
  end
end 
