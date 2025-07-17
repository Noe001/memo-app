module Api
  module V2
    class SessionsController < BaseController
      skip_before_action :authenticate_api_user!, only: [:create]

      def create
        email = params[:email]
        password = params[:password]

        if email.blank? || password.blank?
          render json: { error: 'メールアドレスとパスワードを入力してください' }, status: :bad_request
          return
        end

        begin
          auth_result = SupabaseAuth.sign_in(email, password)
          if auth_result[:success]
            render json: {
              success: true,
              message: 'ログインしました',
              user: auth_result[:user],
              access_token: auth_result[:access_token]
            }
          else
            render json: { error: auth_result[:error] || 'ログインに失敗しました' }, status: :unauthorized
          end
        rescue => e
          Rails.logger.error "API Login error: #{e.message}"
          render json: { error: 'ログイン中にエラーが発生しました' }, status: :internal_server_error
        end
      end

      def destroy
        begin
          SupabaseAuth.sign_out(current_user&.supabase_token) if current_user&.supabase_token
        rescue => e
          Rails.logger.error "API Logout error: #{e.message}"
        end

        render json: { success: true, message: 'ログアウトしました' }
      end
    end
  end
end 
