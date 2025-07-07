class ApplicationController < ActionController::Base
  # CSRF保護は必要に応じて設定
  protect_from_forgery with: :null_session, if: -> { request.format.json? }
  
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
  end
  helper_method :current_user_model
  
  def set_current_user
    Rails.logger.info "=== set_current_user called ==="
    
    # Supabase JWTトークンから認証
    supabase_token = extract_supabase_token
    Rails.logger.info "Supabase token: #{supabase_token.present? ? 'present' : 'absent'}"
    
    if supabase_token
      Rails.logger.info "Attempting Supabase token verification..."
      @current_user_data = SupabaseAuth.verify_token(supabase_token)
      Rails.logger.info "Supabase verification result: #{@current_user_data.present? ? 'success' : 'failed'}"
      
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
    
    # Supabase認証の場合、profilesテーブルから元のRails IDを取得
    profile_data = SupabaseAuth.get_user_profile(current_user.id)
    
    if profile_data && profile_data['original_rails_id']
      # 元のRails UserモデルがまだDBに存在する場合
      existing_user = User.find_by(id: profile_data['original_rails_id'])
      return existing_user if existing_user
    end
    
    # 元のUserモデルが見つからない場合、新しいUserモデルを作成（移行期間中の互換性のため）
    create_compatible_user_model(profile_data)
  end
  
  def create_compatible_user_model(profile_data)
    # Supabaseユーザーに対応するUserモデルを作成
    random_password = SecureRandom.alphanumeric(32)
    
    user_attributes = {
      email: current_user.email,
      name: current_user.name,
      theme: current_user.theme || 'light',
      keyboard_shortcuts_enabled: current_user.keyboard_shortcuts_enabled != false,
      password: random_password,
      password_confirmation: random_password
    }
    
    # 既存のメールアドレスチェック
    existing_user = User.find_by(email: current_user.email)
    if existing_user
      # 既存ユーザーがいる場合は、そのユーザーを更新
      existing_user.update!(
        name: user_attributes[:name],
        theme: user_attributes[:theme],
        keyboard_shortcuts_enabled: user_attributes[:keyboard_shortcuts_enabled]
      )
      return existing_user
    end
    
    # 新しいユーザーを作成
    begin
      User.create!(user_attributes)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create compatible user model: #{e.message}"
      # 作成に失敗した場合、既存のユーザーを再検索
      User.find_by(email: current_user.email)
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
      return token
    end
    
    # 2. Cookieから
    cookie_token = cookies['supabase_token']
    Rails.logger.info "Cookie token: #{cookie_token.present? ? 'present' : 'absent'}"
    cookie_token
  end
  
  # Supabaseトークンを設定
  def set_supabase_token(token)
    cookies['supabase_token'] = {
      value: token,
      httponly: true,
      secure: Rails.env.production?,
      expires: 1.hour.from_now
    }
  end
  
  # Supabaseトークンを削除
  def clear_supabase_token
    cookies.delete('supabase_token')
  end
end
