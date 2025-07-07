module Api
  module V2
    class BaseController < ActionController::API
      include ActionController::Cookies
      
      before_action :authenticate_user!
      before_action :set_current_user
      
      private
      
      def set_current_user
        Rails.logger.info "=== API v2 set_current_user called ==="
        
        # Supabase JWTトークンから認証
        supabase_token = extract_supabase_token
        Rails.logger.info "Supabase token: #{supabase_token.present? ? 'present' : 'absent'}"
        
        if supabase_token
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
      
      def current_user
        @current_user
      end
      
      def current_user_model
        return @current_user_model if defined?(@current_user_model)
        
        @current_user_model = get_user_model_instance
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
        Rails.logger.info "=== API v2 authenticate_user! called ==="
        Rails.logger.info "Current user present: #{current_user.present?}"
        
        unless current_user
          Rails.logger.info "Authentication failed - returning unauthorized"
          render json: { error: 'ログインが必要です' }, status: :unauthorized
          return
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
      
      # 成功レスポンス
      def render_success(data = {}, message = nil)
        response_data = { success: true }
        response_data[:data] = data if data.present?
        response_data[:message] = message if message.present?
        
        render json: response_data
      end
      
      # エラーレスポンス
      def render_error(message, status = :unprocessable_entity, errors = nil)
        response_data = { success: false, error: message }
        response_data[:errors] = errors if errors.present?
        
        render json: response_data, status: status
      end
      
      # Supabase APIにプロキシ
      def proxy_to_supabase(endpoint, method: :get, params: {}, body: nil)
        supabase_url = ENV['SUPABASE_URL'] || 'http://localhost:54321'
        supabase_key = ENV['SUPABASE_ANON_KEY'] || 'your-anon-key'
        
        url = "#{supabase_url}/rest/v1#{endpoint}"
        
        headers = {
          'Content-Type' => 'application/json',
          'apikey' => supabase_key,
          'Authorization' => "Bearer #{current_user&.supabase_token || supabase_key}"
        }
        
        # パラメータをURLに追加
        if params.present? && method == :get
          url += "?#{params.to_query}"
        end
        
        begin
          response = case method
                     when :get
                       HTTParty.get(url, headers: headers)
                     when :post
                       HTTParty.post(url, headers: headers, body: body.to_json)
                     when :patch
                       HTTParty.patch(url, headers: headers, body: body.to_json)
                     when :delete
                       HTTParty.delete(url, headers: headers)
                     else
                       raise "Unsupported HTTP method: #{method}"
                     end
          
          if response.success?
            render json: response.parsed_response
          else
            render json: { error: "Supabase API error: #{response.code}" }, status: response.code
          end
        rescue => e
          Rails.logger.error "Supabase API error: #{e.message}"
          render json: { error: "Internal server error" }, status: :internal_server_error
        end
      end
    end
  end
end 
