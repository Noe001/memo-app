class UsersController < ApplicationController

  def signup
    @user = User.new
  end

  def create
    @user = User.new(users_params)
    if @user.save
      redirect_to new_sessions_path, notice: 'アカウントが作成されました'
    else
      flash.now[:alert] = "パスワードが一致していません"
      render :signup
    end
    p "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    p  @user.errors.full_messages.to_sentence
  end

  private

  def users_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

end
