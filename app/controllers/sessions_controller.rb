class SessionsController < ApplicationController
  before_action :set_user, only: [:create, :destroy]
  before_action :logged_in, only: [:new, :create]

  def new
  end

  def create
    if @user.authenticate(params[:password])
      session[:user_id] = @user.id
      redirect_to memos_path, notice: 'ログインしました。'
    else
      flash.now[:alert] = 'メールアドレスまたはパスワードが無効です。'
      render :new, status: :unauthorized
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to new_sessions_path, notice: 'ログアウトしました。'
  end

  private

  def set_user
    @user = User.find_by(email: params[:email])
  end

  def logged_in
    if session[:user_id]
      @user = User.find(session[:user_id])
      redirect_to memos_path, notice: 'ログインしています'
    end
  end
end
