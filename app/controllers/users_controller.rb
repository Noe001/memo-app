class UsersController < ApplicationController
  before_action :authenticate_user!, except: [:signup, :create]
  
  def signup
    # Phase 4移行: AuthControllerに統一
    redirect_to auth_login_path
  end

  def create
    # Phase 4移行: AuthControllerに統一
    redirect_to auth_login_path
  end
  
  # プロファイル表示
  # This action is intended to show the current_user's profile.
  # The route resources :users implies /users/:id, but this controller
  # consistently uses current_user for show, edit, update.
  # This should ideally be a singular resource route like /profile.
  def show
    @user = current_user # Explicitly for the logged-in user
    if @user.nil? # Should not happen if authenticate_user! works
      redirect_to new_sessions_path, alert: 'ログインしてください。'
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
    @user = current_user
    if @user.nil?
      redirect_to new_sessions_path, alert: 'ログインしてください。'
      return
    end
    @memos_count = @user.memos.count
    @recent_memos = @user.memos.recent.limit(5)
    render :show # Render the same view as the show action
  end
  
  # プロファイル編集
  def edit
    @user = current_user
  end
  
  def update
    @user = current_user_model
    
    if @user.update(update_user_params)
      redirect_to user_path(@user), notice: 'プロファイルを更新しました'
    else
      handle_validation_errors
      render :edit, status: :unprocessable_entity
    end
  end

  private
  
  def update_user_params
    # パスワード更新時のみpasswordフィールドを許可
    permitted = [:name, :email]
    permitted += [:password, :password_confirmation] if params[:user][:password].present?
    params.require(:user).permit(permitted)
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
