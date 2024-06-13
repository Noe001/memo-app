class SessionsController < ApplicationController
  before_action :logged_in, only: [:new, :create]

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
    session[:user_id] = nil
    redirect_to new_sessions_path, notice: 'ログアウトしました。'
  end

  private

  def logged_in
    if session[:user_id]
      @user = User.find(session[:user_id])
      flash[:notice] = "ログインしています"
      redirect_to memos_path
    end
  end
end
