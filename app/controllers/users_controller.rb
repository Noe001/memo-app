class UsersController < ApplicationController

  def signup
    @user = User.new
  end

  def create
    @user = User.new(users_params)
    if @user.save
      redirect_to new_sessions_path, notice: 'アカウントが作成されました'
    else
      messages = @user.errors.messages
      if messages[:password_confirmation].present?
        flash.now[:alert] = 'パスワードが一致しません' 
      elsif messages[:email].include?('has already been taken')
        flash.now[:alert] = '入力したメールアドレスは既に存在します' 
      end
      render :signup
    end
  end

  private

  def users_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

end
