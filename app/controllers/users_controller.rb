class UsersController < ApplicationController
  before_action :redirect_if_logged_in, only: [:signup, :create]

  def signup
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    
    if @user.save
      # アカウント作成ログ
      Rails.logger.info "New user created: #{@user.email} from IP: #{request.remote_ip}"
      
      # 自動ログイン（オプション - セキュリティ要件に応じて）
      # session[:user_id] = @user.id
      
      redirect_to new_sessions_path, notice: 'アカウントが作成されました。ログインしてください。'
    else
      # バリデーションエラーの詳細処理
      handle_validation_errors
      render :signup, status: :unprocessable_entity
    end
  end
  
  # プロファイル表示（今後の機能拡張用）
  def show
    authenticate_user!
    @user = current_user
    @memos_count = @user.memos.count
    @recent_memos = @user.memos.recent.limit(5)
  end
  
  # プロファイル編集（今後の機能拡張用）
  def edit
    authenticate_user!
    @user = current_user
  end
  
  def update
    authenticate_user!
    @user = current_user
    
    if @user.update(update_user_params)
      redirect_to user_path(@user), notice: 'プロファイルを更新しました'
    else
      handle_validation_errors
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
  
  def update_user_params
    # パスワード更新時のみpasswordフィールドを許可
    permitted = [:name, :email]
    permitted += [:password, :password_confirmation] if params[:user][:password].present?
    params.require(:user).permit(permitted)
  end
  
  def redirect_if_logged_in
    if current_user
      redirect_to root_path, notice: '既にログインしています'
    end
  end
  
  def handle_validation_errors
    messages = @user.errors.messages
    
    if messages[:password_confirmation].present?
      flash.now[:alert] = 'パスワードが一致しません'
    elsif messages[:email]&.include?('has already been taken')
      flash.now[:alert] = '入力したメールアドレスは既に使用されています'
    elsif messages[:password].present?
      if messages[:password].include?('is too short (minimum is 8 characters)')
        flash.now[:alert] = 'パスワードは8文字以上で入力してください'
      elsif messages[:password].first.include?('must include')
        flash.now[:alert] = 'パスワードは大文字・小文字・数字・特殊文字を含む必要があります'
      else
        flash.now[:alert] = 'パスワードの形式が正しくありません'
      end
    elsif messages[:email].present?
      flash.now[:alert] = 'メールアドレスの形式が正しくありません'
    elsif messages[:name].present?
      flash.now[:alert] = '名前は2文字以上50文字以下で入力してください'
    else
      flash.now[:alert] = '入力内容にエラーがあります'
    end
  end
end
