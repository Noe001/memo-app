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
    
    @current_user_model = get_user_model_instance
    @current_user_model
  end
  helper_method :current_user_model
  
  def set_current_user
    tokens = extract_supabase_token
    supabase_access_token = tokens[:access_token]
    supabase_refresh_token = tokens[:refresh_token]

    if supabase_access_token
      @current_user_data = SupabaseAuth.verify_token(supabase_access_token)

      unless @current_user_data
        if supabase_refresh_token
          refresh_result = SupabaseAuth.refresh_token(supabase_refresh_token)
          if refresh_result[:success]
            new_access_token = refresh_result[:access_token]
            new_refresh_token = refresh_result[:refresh_token]
            set_supabase_token(new_access_token, new_refresh_token)
            @current_user_data = SupabaseAuth.verify_token(new_access_token)
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
        return
      end
    end
    
    @current_user = nil
  end
  
  def get_user_model_instance
    return nil unless current_user&.auth_method == 'supabase'
    
    begin
      existing_user = User.find_by(email: current_user.email)
      return existing_user if existing_user
      
      profile_data = SupabaseAuth.get_user_profile(current_user.id)
      
      if profile_data && profile_data['original_rails_id']
        existing_user = User.find_by(id: profile_data['original_rails_id'])
        return existing_user if existing_user
      end
      
      create_compatible_user_model(profile_data)
    rescue => e
      Rails.logger.error "Error getting user model instance: #{e.message}" if Rails.env.development?
      nil
    end
  end
  
  def create_compatible_user_model(profile_data)
    random_password = SecureRandom.alphanumeric(32)
    
    user_attributes = {
      email: current_user.email,
      name: (current_user.name.present? && current_user.name.length >= 2) ? current_user.name : 'User',
      theme: current_user.theme || 'light',
      keyboard_shortcuts_enabled: current_user.keyboard_shortcuts_enabled != false,
      password: random_password,
      password_confirmation: random_password
    }
    
    existing_user = User.find_by(email: current_user.email)
    if existing_user
      begin
        existing_user.update!(
          name: (user_attributes[:name].present? && user_attributes[:name].length >= 2) ? user_attributes[:name] : 'User',
          theme: user_attributes[:theme],
          keyboard_shortcuts_enabled: user_attributes[:keyboard_shortcuts_enabled]
        )
        return existing_user
      rescue => e
        Rails.logger.error "Failed to update existing user: #{e.message}" if Rails.env.development?
        return existing_user
      end
    end
    
    begin
      new_user = User.create!(user_attributes)
      return new_user
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create compatible user model: #{e.message}" if Rails.env.development?
      fallback_user = User.find_by(email: current_user.email)
      return fallback_user
    rescue => e
      Rails.logger.error "Unexpected error creating user: #{e.message}" if Rails.env.development?
      return nil
    end
  end
  
  def authenticate_user!
    return if current_user
    
    respond_to do |format|
      format.html { redirect_to login_path, alert: 'ログインしてください' }
      format.json { render json: { status: 'error', message: 'ログインが必要です' }, status: :unauthorized }
    end
  end
  
  # Supabaseトークンを抽出
  def extract_supabase_token
    auth_header = request.headers['Authorization']
    if auth_header&.start_with?('Bearer ')
      token = auth_header.split(' ').last
      return { access_token: token, refresh_token: nil }
    end
    
    access_token = cookies['supabase_token']
    refresh_token = cookies['supabase_refresh_token']
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
