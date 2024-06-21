class MemosController < ApplicationController
  # ユーザーがログインしていることを確認
  before_action :current_user

  def index
    @memo_new = Memo.new
    # ログインしたユーザーが作成したメモのみを取得
    @memos = current_user.memos
  end

  def create
    # ログインしたユーザーに関連付けられたメモを作成
    @memo_new = current_user.memos.build(memos_params)
    @memo_new.save
    # タイトルと概要が空の場合はメモを削除
    if @memo_new.title.blank? && @memo_new.description.blank?
      @memo_new.destroy
      redirect_to root_path, alert: 'タイトルと概要を入力してください'
    else
      redirect_to root_path, notice: '作成しました'
    end
  end

  def update
    # メモの内容を更新
    @memo = current_user.memos.find(params[:id])
    @memo.update(memos_params)
    if @memo.title.blank? && @memo.description.blank?
      @memo.destroy
      redirect_to root_path, notice: '未入力だったため削除されました'
    else
      redirect_to root_path, notice: '更新しました'
    end
  end

  def destroy
    # メモを削除
    @memo = current_user.memos.find(params[:id])
    @memo.destroy
    redirect_to root_path, notice: 'メモが削除されました'
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