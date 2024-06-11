class SessionsController < ApplicationController

  def new

  end

  def create
    @user = User.find_by(email: params[:email], password: params[:password])
    if @user
      sessions[:user_id] = @user.id
      flash[:notice] = "ログインに成功しました"
      redirect_to memo_path
    else
      flash[:alert] - "ログインに失敗しました"
      require actiom: "new"
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to new_sessions_path
  end

end
