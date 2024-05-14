class SessionsController < ApplicationController
  class SessionsController < ApplicationController
    before_action :logged_in?, only: [:new, :create]
 
    def new
    end
 
    def create
        @user = User.find_by(email: params[:email], password: params[:password])
        if @user
            session[:user_id] = @user.id
            flash[:notice] = "ログインに成功しました。"
            redirect_to memos_path
        else
            flash[:alert] = "ログインに失敗しました。"
            render action: "new"
        end
    end
 
    def destroy
        session[:user_id] = nil
        redirect_to new_sessions_path
    end
 
    private
 
    def logged_in?
        if session[:user_id]
            @user = User.find(session[:user_id])
            flash[:notice] = "すでにログインしています。"
            redirect_to memos_path
        end
    end
  end
end
