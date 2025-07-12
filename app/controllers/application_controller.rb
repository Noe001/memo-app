class ApplicationController < ActionController::Base
  # CSRF保護はデフォルトで有効になっています。
  # APIエンドポイントや特定のケースで無効化する場合は、対象のコントローラーで個別に設定してください。
  # 例: protect_from_forgery with: :null_session, if: -> { request.format.json? }
  protect_from_forgery with: :exception, unless: -> { request.format.json? }
  
  before_action :set_current_user
  
  private
  
  def current_user
    @current_user
  end
  helper_method :current_user
  
  # ActiveRecordのUserモデルインスタンスを取得（既存メモとの関連付け用）
  def current_user_model
    return @current_user_model if defined?(@current_user_model)
    
    Rails.logger.info "Getting current_user_model, current_user present: #{current_user.present?}"
    @current_user_model = get_user_model_instance
    Rails.logger.info "current_user_model result: #{@current_user_model.present? ? 'present' : 'nil'}"
    @current_user_model
  end
  helper_method :current_user_model
  
  def set_current_user
    Rails.logger.info "=== set_current_user called ==="
    
    # Supabase JWTトークンから認証
    tokens = extract_supabase_token
    supabase_access_token = tokens[:access_token]
    supabase_refresh_token = tokens[:refresh_token]

    Rails.logger.info "Supabase access token: #{supabase_access_token.present? ? 'present' : 'absent'}"
    Rails.logger.info "Supabase refresh token: #{supabase_refresh_token.present? ? 'present' : 'absent'}"

    if supabase_access_token
      Rails.logger.info "Attempting Supabase access token verification..."
      @current_user_data = SupabaseAuth.verify_token(supabase_access_token)
      Rails.logger.info "Supabase access token verification result: #{@current_user_data.present? ? 'success' : 'failed'}"

      unless @current_user_data
        # アクセストークンが無効な場合、リフレッシュトークンを試す
        if supabase_refresh_token
          Rails.logger.info "Access token invalid, attempting to refresh token..."
          refresh_result = SupabaseAuth.refresh_token(supabase_refresh_token)
          if refresh_result[:success]
            Rails.logger.info "Token refreshed successfully."
            new_access_token = refresh_result[:access_token]
            new_refresh_token = refresh_result[:refresh_token]
            set_supabase_token(new_access_token, new_refresh_token) # 新しいトークンをクッキーに保存
            @current_user_data = SupabaseAuth.verify_token(new_access_token) # 新しいアクセストークンで再検証
            Rails.logger.info "New access token verification result: #{@current_user_data.present? ? 'success' : 'failed'}"
          else
            Rails.logger.warn "Failed to refresh token: #{refresh_result[:error]}"
          end
        end
      end

      if @current_user_data
        @current_user = OpenStruct.new(
          id: @current_user_data[:id],
          email: @current_user_data[:email],
          name: @current_user_data[:name],
          theme: @current_user_data[:theme],
          keyboard_shortcuts_enabled: @current_user_data[:keyboard_shortcuts_enabled],
          supabase_token: @current_user_data[:token],
          auth_method: 'supabase'
        )
        Rails.logger.info "Current user set via Supabase: #{@current_user.email}"
        return
      end
    end
    
    # 認証されていない場合
    Rails.logger.info "No authentication found - setting current_user to nil"
    @current_user = nil
  end
  
  def get_user_model_instance
    return nil unless current_user&.auth_method == 'supabase'
    
    Rails.logger.info "Getting user model instance for: #{current_user.email}"
    
    begin
      # まず既存のメールアドレスでUserモデルを検索
      existing_user = User.find_by(email: current_user.email)
      if existing_user
        Rails.logger.info "Found existing user by email: #{existing_user.email}"
        return existing_user
      end
      
      # Supabase認証の場合、profilesテーブルから元のRails IDを取得
      profile_data = SupabaseAuth.get_user_profile(current_user.id)
      Rails.logger.info "Profile data: #{profile_data.present? ? 'present' : 'absent'}"
      
      if profile_data && profile_data['original_rails_id']
        # 元のRails UserモデルがまだDBに存在する場合
        existing_user = User.find_by(id: profile_data['original_rails_id'])
        if existing_user
          Rails.logger.info "Found existing user by original_rails_id: #{existing_user.email}"
          return existing_user
        end
      end
      
      # 元のUserモデルが見つからない場合、新しいUserモデルを作成（移行期間中の互換性のため）
      Rails.logger.info "Creating compatible user model"
      create_compatible_user_model(profile_data)
    rescue => e
      Rails.logger.error "Error getting user model instance: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
  end
  
  def create_compatible_user_model(profile_data)
    Rails.logger.info "Creating compatible user model for: #{current_user.email}"
    
    # Supabaseユーザーに対応するUserモデルを作成
    random_password = SecureRandom.alphanumeric(32)
    
    user_attributes = {
      email: current_user.email,
      name: (current_user.name.present? && current_user.name.length >= 2) ? current_user.name : 'User',
      theme: current_user.theme || 'light',
      keyboard_shortcuts_enabled: current_user.keyboard_shortcuts_enabled != false,
      password: random_password,
      password_confirmation: random_password
    }
    
    Rails.logger.info "User attributes: #{user_attributes.except(:password, :password_confirmation)}"
    
    # 既存のメールアドレスチェック
    existing_user = User.find_by(email: current_user.email)
    if existing_user
      Rails.logger.info "Found existing user by email: #{existing_user.email}"
      # 既存ユーザーがいる場合は、そのユーザーを更新
      begin
        existing_user.update!(
          name: (user_attributes[:name].present? && user_attributes[:name].length >= 2) ? user_attributes[:name] : 'User',
          theme: user_attributes[:theme],
          keyboard_shortcuts_enabled: user_attributes[:keyboard_shortcuts_enabled]
        )
        Rails.logger.info "Updated existing user successfully"
        return existing_user
      rescue => e
        Rails.logger.error "Failed to update existing user: #{e.message}"
        return existing_user # 更新に失敗してもユーザーは返す
      end
    end
    
    # 新しいユーザーを作成
    begin
      new_user = User.create!(user_attributes)
      Rails.logger.info "Created new user successfully: #{new_user.email}"
      return new_user
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create compatible user model: #{e.message}"
      Rails.logger.error "Validation errors: #{e.record.errors.full_messages.join(', ')}"
      # 作成に失敗した場合、既存のユーザーを再検索
      fallback_user = User.find_by(email: current_user.email)
      Rails.logger.info "Fallback user found: #{fallback_user.present?}"
      return fallback_user
    rescue => e
      Rails.logger.error "Unexpected error creating user: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return nil
    end
  end
  
  def authenticate_user!
    Rails.logger.info "=== authenticate_user! called ==="
    Rails.logger.info "Current user present: #{current_user.present?}"
    
    return if current_user
    
    Rails.logger.info "Authentication failed - redirecting to login"
    respond_to do |format|
      format.html { redirect_to auth_login_path, alert: 'ログインしてください' }
      format.json { render json: { status: 'error', message: 'ログインが必要です' }, status: :unauthorized }
    end
  end
  
  # Supabaseトークンを抽出
  def extract_supabase_token
    # 1. Authorizationヘッダーから
    auth_header = request.headers['Authorization']
    if auth_header&.start_with?('Bearer ')
      token = auth_header.split(' ').last
      Rails.logger.info "Token extracted from Authorization header: #{token.present? ? 'present' : 'absent'}"
      return { access_token: token, refresh_token: nil }
    end
    
    # 2. Cookieから
    access_token = cookies['supabase_token']
    refresh_token = cookies['supabase_refresh_token']
    Rails.logger.info "Cookie access token: #{access_token.present? ? 'present' : 'absent'}"
    Rails.logger.info "Cookie refresh token: #{refresh_token.present? ? 'present' : 'absent'}"
    { access_token: access_token, refresh_token: refresh_token }
  end
  
  # Supabaseトークンを設定
  def set_supabase_token(access_token, refresh_token = nil)
    cookies['supabase_token'] = {
      value: access_token,
      httponly: true,
      secure: Rails.env.production?
    }
    if refresh_token
      cookies['supabase_refresh_token'] = {
        value: refresh_token,
        httponly: true,
        secure: Rails.env.production?
      }
    end
  end
  
  # Supabaseトークンを削除
  def clear_supabase_token
    cookies.delete('supabase_token')
  end
end
