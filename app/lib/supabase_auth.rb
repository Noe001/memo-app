require 'jwt'
require 'net/http'
require 'json'

class SupabaseAuth
  # DockerコンテナからSupabaseにアクセスするため、複数のホストを試行
  SUPABASE_HOSTS = [
    'supabase_kong_memo-app',  # Supabase コンテナ名
    'host.docker.internal',
    '172.17.0.1',        # Docker デフォルトゲートウェイ
    'host-gateway',      # Docker Compose host-gateway
    '127.0.0.1'          # ローカルホスト（非Docker環境用）
  ].freeze
  
  SUPABASE_PORT = 8000  # Supabaseコンテナ内のポート
  SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
  JWT_SECRET = 'super-secret-jwt-token-with-at-least-32-characters-long'
  
  # 利用可能なSupabaseホストを検索
  def self.find_available_supabase_host
    return @available_host if @available_host
    
    SUPABASE_HOSTS.each do |host|
      begin
        # Supabaseコンテナの場合は8000ポート、それ以外は54321ポート
        port = host == 'supabase_kong_memo-app' ? 8000 : 54321
        uri = URI("http://#{host}:#{port}/health")
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 2
        http.read_timeout = 2
        
        response = http.request(Net::HTTP::Get.new(uri))
        if response.code == '200'
          @available_host = host
          Rails.logger.info "Found available Supabase host: #{host}"
          return host
        end
      rescue => e
        Rails.logger.debug "Supabase host #{host} not available: #{e.message}"
      end
    end
    
    # デフォルトにフォールバック
    @available_host = 'host.docker.internal'
    Rails.logger.warn "No Supabase host found, using default: #{@available_host}"
    @available_host
  end
  
  def self.supabase_url
    host = find_available_supabase_host
    port = host == 'supabase_kong_memo-app' ? 8000 : 54321
    @supabase_url ||= "http://#{host}:#{port}"
  end
  
  # JWTトークンを検証し、ユーザー情報を返す
  def self.verify_token(token)
    return nil unless token
    
    begin
      Rails.logger.info "SupabaseAuth.verify_token called with token: #{token.present? ? 'present' : 'absent'}"
      
      # Supabase APIを使用してトークンを検証
      user_data = get_user_from_supabase(token)
      Rails.logger.info "get_user_from_supabase result: #{user_data.present? ? 'success' : 'failed'}"
      
      return nil unless user_data
      
      # JWTトークンをデコード（検証なし）して追加情報を取得
      decoded_token = JWT.decode(token, nil, false)
      payload = decoded_token[0]
      Rails.logger.info "JWT decoded successfully"
      
      # トークンの有効期限を確認
      if payload['exp'] && payload['exp'] < Time.now.to_i
        Rails.logger.warn "Token expired: #{payload['exp']} < #{Time.now.to_i}"
        return nil
      end
      
      # プロフィール情報を取得
      profile_data = get_user_profile(user_data['id'])
      Rails.logger.info "Profile data: #{profile_data.present? ? 'found' : 'not found'}"
      
      result = {
        id: user_data['id'],
        email: user_data['email'],
        role: user_data['role'] || 'authenticated',
        name: profile_data&.dig('name') || user_data['email']&.split('@')&.first,
        theme: profile_data&.dig('theme') || 'light',
        keyboard_shortcuts_enabled: profile_data&.dig('keyboard_shortcuts_enabled') != false,
        token: token
      }
      
      Rails.logger.info "Token verification successful for user: #{result[:email]}"
      result
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT decode error: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Supabase auth error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
  end
  
  # Supabase APIからユーザー情報を取得
  def self.get_user_from_supabase(token)
    uri = URI("#{supabase_url}/auth/v1/user")
    Rails.logger.info "Making request to: #{uri}"
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{token}"
    request['apikey'] = SUPABASE_ANON_KEY
    
    Rails.logger.info "Request headers: Authorization=Bearer #{token[0..20]}..., apikey=#{SUPABASE_ANON_KEY[0..20]}..."
    
    response = http.request(request)
    Rails.logger.info "Response code: #{response.code}"
    Rails.logger.info "Response body (first 200 chars): #{response.body[0..200]}"
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      Rails.logger.error "Failed to get user from Supabase: #{response.code} #{response.body}"
      nil
    end
  end
  
  # プロフィール情報をSupabaseから取得
  def self.get_user_profile(user_id)
    uri = URI("#{supabase_url}/rest/v1/profiles?id=eq.#{user_id}&select=*")
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{SUPABASE_ANON_KEY}"
    request['apikey'] = SUPABASE_ANON_KEY
    request['Content-Type'] = 'application/json'
    
    response = http.request(request)
    
    if response.code == '200'
      profiles = JSON.parse(response.body)
      profiles.first
    else
      Rails.logger.warn "Failed to get profile from Supabase: #{response.code} #{response.body}"
      nil
    end
  end
  
  # Supabaseでパスワードリセットリンクを生成
  def self.generate_password_reset_link(email)
    uri = URI("#{supabase_url}/auth/v1/recover")
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{SUPABASE_ANON_KEY}"
    request['apikey'] = SUPABASE_ANON_KEY
    request['Content-Type'] = 'application/json'
    request.body = { email: email }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      Rails.logger.error "Failed to generate reset link: #{response.code} #{response.body}"
      nil
    end
  end
  
  # ログイン処理
  def self.sign_in(email, password)
    uri = URI("#{supabase_url}/auth/v1/token?grant_type=password")
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{SUPABASE_ANON_KEY}"
    request['apikey'] = SUPABASE_ANON_KEY
    request['Content-Type'] = 'application/json'
    request.body = { 
      email: email, 
      password: password 
    }.to_json
    
    Rails.logger.info "Sign in request to: #{uri}"
    Rails.logger.info "Request body: #{request.body}"
    
    response = http.request(request)
    Rails.logger.info "Sign in response code: #{response.code}"
    Rails.logger.info "Sign in response body: #{response.body}"
    
    if response.code == '200'
      data = JSON.parse(response.body)
      
             # プロフィール情報を取得または作成
       profile_data = get_user_profile(data['user']['id'])
       if profile_data.nil?
         create_user_profile(data['user']['id'], data['user']['email'], nil, data['access_token'])
         profile_data = get_user_profile(data['user']['id'])
       end
      
      {
        success: true,
        access_token: data['access_token'],
        refresh_token: data['refresh_token'],
        user: {
          id: data['user']['id'],
          email: data['user']['email'],
          name: profile_data&.dig('name') || data['user']['email']&.split('@')&.first,
          theme: profile_data&.dig('theme') || 'light',
          keyboard_shortcuts_enabled: profile_data&.dig('keyboard_shortcuts_enabled') != false
        }
      }
    else
      error_data = JSON.parse(response.body) rescue { 'error' => 'Unknown error' }
      Rails.logger.error "Sign in failed: #{error_data}"
      
      {
        success: false,
        error: error_data.dig('error_description') || error_data.dig('error') || 'ログインに失敗しました'
      }
    end
  rescue => e
    Rails.logger.error "Sign in error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    {
      success: false,
      error: 'ログイン中にエラーが発生しました'
    }
  end
  
  # サインアップ処理
  def self.sign_up(email, password, name)
    uri = URI("#{supabase_url}/auth/v1/signup")
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{SUPABASE_ANON_KEY}"
    request['apikey'] = SUPABASE_ANON_KEY
    request['Content-Type'] = 'application/json'
    request.body = { 
      email: email, 
      password: password,
      data: { name: name }
    }.to_json
    
    Rails.logger.info "Sign up request to: #{uri}"
    Rails.logger.info "Request body: #{request.body}"
    
    response = http.request(request)
    Rails.logger.info "Sign up response code: #{response.code}"
    Rails.logger.info "Sign up response body: #{response.body}"
    
    if response.code == '200'
      data = JSON.parse(response.body)
      
      # プロフィール作成（ユーザーのアクセストークンを使用）
      create_user_profile(data['user']['id'], email, name, data['access_token'])
      
      {
        success: true,
        access_token: data['access_token'],
        refresh_token: data['refresh_token'],
        user: {
          id: data['user']['id'],
          email: data['user']['email'],
          name: name,
          theme: 'light',
          keyboard_shortcuts_enabled: true
        }
      }
    else
      error_data = JSON.parse(response.body) rescue { 'error' => 'Unknown error' }
      Rails.logger.error "Sign up failed: #{error_data}"
      
      {
        success: false,
        error: error_data.dig('error_description') || error_data.dig('error') || 'アカウント作成に失敗しました'
      }
    end
  rescue => e
    Rails.logger.error "Sign up error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    {
      success: false,
      error: 'アカウント作成中にエラーが発生しました'
    }
  end
  
  # プロフィール作成
  def self.create_user_profile(user_id, email, name = nil, access_token = nil)
    uri = URI("#{supabase_url}/rest/v1/profiles")
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    # ユーザーのアクセストークンがある場合はそれを使用、なければAnonキー
    auth_token = access_token || SUPABASE_ANON_KEY
    request['Authorization'] = "Bearer #{auth_token}"
    request['apikey'] = SUPABASE_ANON_KEY
    request['Content-Type'] = 'application/json'
    request['Prefer'] = 'return=minimal'
    request.body = {
      id: user_id,
      email: email,
      name: name || email.split('@').first,
      theme: 'light',
      keyboard_shortcuts_enabled: true
    }.to_json
    
    Rails.logger.info "Create profile request to: #{uri}"
    Rails.logger.info "Request body: #{request.body}"
    
    response = http.request(request)
    Rails.logger.info "Create profile response code: #{response.code}"
    Rails.logger.info "Create profile response body: #{response.body}"
    
    response.code == '201'
  rescue => e
    Rails.logger.error "Create profile error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end
  
  # トークンリフレッシュ
  def self.refresh_token(refresh_token)
    uri = URI("#{supabase_url}/auth/v1/token?grant_type=refresh_token")
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{SUPABASE_ANON_KEY}"
    request['apikey'] = SUPABASE_ANON_KEY
    request['Content-Type'] = 'application/json'
    request.body = { refresh_token: refresh_token }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      {
        success: true,
        access_token: data['access_token'],
        refresh_token: data['refresh_token'],
        user: data['user']
      }
    else
      {
        success: false,
        error: 'トークンの更新に失敗しました'
      }
    end
  rescue => e
    Rails.logger.error "Refresh token error: #{e.message}"
    {
      success: false,
      error: 'トークン更新中にエラーが発生しました'
    }
  end
  
  # サインアウト処理
  def self.sign_out(token)
    return true unless token
    
    uri = URI("#{supabase_url}/auth/v1/logout")
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{token}"
    request['apikey'] = SUPABASE_ANON_KEY
    request['Content-Type'] = 'application/json'
    
    response = http.request(request)
    response.code == '204'
  rescue => e
    Rails.logger.error "Sign out error: #{e.message}"
    true # サインアウトエラーは無視
  end
  
  # ログアウト処理（後方互換性のため）
  def self.logout(token)
    sign_out(token)
  end
end 
