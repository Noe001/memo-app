class MemosController < ApplicationController
  before_action :current_user

  def index
    @memo_new = Memo.new
    @memos = Memo.all
  end

  def create
    @memo_new = Memo.new(memos_params)
    @memo_new.save
    redirect_to root_path
  end

  def update
    @memo_id = Memo.find(params[:id])
    @memo_id.update(memos_params)
    redirect_to root_path
  end

  def destroy
    @memo_id = Memo.find(params[:id])
    @memo_id.destroy
    redirect_to root_path
  end

  private

  def memos_params
    params.require(:memo).permit(:title, :description)
  end

  def current_user
    if session[:user_id]
      @user = User.find(session[:user_id])
    else
      redirect_to new_sessions_path
    end
  end

end
