class SessionsController < ApplicationController

  def new
  end

  def create
    @user = User.find_by(email: params[:email], password: params[:password])
    if @user
      session[:user_id] = @user.id
      redirect_to memos_path, notice: 'ログインしました。'
    else
      flash.now[:alert] = 'メールアドレスまたはパスワードが無効です。'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    p session[:user_id]
    session[:user_id] = nil
    redirect_to new_sessions_path, notice: 'ログアウトしました。'
    p "ddddddddddddddddddddddddddddddddddd"
    p session[:user_id]
  end
end
