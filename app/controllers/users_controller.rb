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
  
  # プロファイル表示
  # This action is intended to show the current_user's profile.
  # The route resources :users implies /users/:id, but this controller
  # consistently uses current_user for show, edit, update.
  # This should ideally be a singular resource route like /profile.
  def show
    authenticate_user!
    @user = current_user # Explicitly for the logged-in user
    if @user.nil? # Should not happen if authenticate_user! works
      redirect_to login_path, alert: 'ログインしてください。'
      return
    end
    @memos_count = @user.memos.count
    @recent_memos = @user.memos.recent.limit(5)
    # Renders show.html.erb
  end

  # Profile route /users/:id/profile.
  # Given current setup, this will also show current_user's profile, similar to show.
  # If :id was intended to be used, authorization would be needed.
  def profile
    authenticate_user!
    # If params[:id] should be used to view other's profiles (not current design):
    # @user = User.find(params[:id])
    # authorize_user_profile_view!(@user) # Some authorization logic
    # else, it's for current_user:
    @user = current_user
    if @user.nil?
      redirect_to login_path, alert: 'ログインしてください。'
      return
    end
    @memos_count = @user.memos.count
    @recent_memos = @user.memos.recent.limit(5)
    render :show # Render the same view as the show action
  end
  
  # プロファイル編集
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
    # 全てのバリデーションエラーメッセージを表示
    if @user.errors.any?
      flash.now[:alert] = @user.errors.full_messages.join(', ')
    else
      flash.now[:alert] = '入力内容にエラーがあります' # Fallback, should not be reached if errors exist
    end
  end
end
